import Foundation
import Combine
import SwiftUI
import Supabase

/// Central app store. Currently backed by Supabase (Auth + Postgres).
@MainActor
class DataStore: ObservableObject {
    static let shared = DataStore()

    // MARK: - Auth State
    @Published var currentUser: User?
    @Published var isAuthenticated = false

    // MARK: - Data Collections
    @Published var users: [User] = []
    @Published var groups: [Group] = []
    @Published var memberships: [Membership] = []
    @Published var nights: [Night] = []
    @Published var mediaItems: [MediaItem] = []
    @Published var voteCases: [VoteCase] = []
    @Published var votes: [Vote] = []
    @Published var notifications: [AppNotification] = []

    // MARK: - Banner State
    @Published var bannerNotification: AppNotification?

    private var timerCancellable: AnyCancellable?
    private let supabase = SupabaseService.client

    private init() {
        Task { await observeAuthState() }
        startVoteResolutionTimer()
    }

    // MARK: - Auth

    enum SignUpResult { case loggedIn, needsEmailVerification, failed }

    @discardableResult
    func signUp(name: String, username: String, email: String, password: String) async -> SignUpResult {
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty, !name.isEmpty, !trimmedUsername.isEmpty else { return .failed }

        do {
            // Store name/username in Auth metadata so trigger can create the profile row.
            let metadata: [String: AnyJSON] = [
                "name": .string(name),
                "username": .string(trimmedUsername)
            ]
            let response = try await supabase.auth.signUp(
                email: trimmedEmail,
                password: password,
                data: metadata
            )

            // If a session was returned, the user is logged in immediately (email confirmation disabled).
            if response.session != nil {
                return .loggedIn
            }
            // No session → email confirmation is required.
            return .needsEmailVerification
        } catch {
            debugPrint("Supabase signUp error:", error)
            return .failed
        }
    }

    @discardableResult
    func login(email: String, password: String) async -> Bool {
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else { return false }
        do {
            _ = try await supabase.auth.signIn(email: trimmedEmail, password: password)
            // Auth listener will populate `currentUser` + data.
            return true
        } catch {
            debugPrint("Supabase login error:", error)
            return false
        }
    }

    func logout() async {
        do { try await supabase.auth.signOut() } catch { debugPrint("Supabase signOut error:", error) }
        currentUser = nil
        isAuthenticated = false
        // Clear cached data
        users = []
        groups = []
        memberships = []
        nights = []
        mediaItems = []
        voteCases = []
        votes = []
        notifications = []
    }

    /// Update current user's profile. Pass currentPassword to change email or password; must match stored password.
    @discardableResult
    func updateProfile(avatarImageData: Data?, name: String?, username: String?, email: String?, newPassword: String?, currentPassword: String?) async -> (success: Bool, error: String?) {
        guard isAuthenticated else { return (false, "Not signed in.") }
        do {
            let currentAuthUser = try await supabase.auth.session.user

            // Update Auth email/password if provided
            if email != nil || newPassword != nil {
                guard let cp = currentPassword, !cp.isEmpty else {
                    return (false, "Enter your current password to change email or password.")
                }
                // Re-authenticate by signing in again (verifies current password)
                _ = try await supabase.auth.signIn(email: currentAuthUser.email ?? "", password: cp)
            }

            if let newEmail = email?.lowercased().trimmingCharacters(in: .whitespaces), !newEmail.isEmpty {
                guard newEmail.contains("@"), newEmail.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).count == 2 else {
                    return (false, "Please enter a valid email address (must contain @).")
                }
                try await supabase.auth.update(user: UserAttributes(email: newEmail))
            }

            if let newPass = newPassword, !newPass.isEmpty {
                guard newPass.count >= 6 else { return (false, "New password must be at least 6 characters.") }
                try await supabase.auth.update(user: UserAttributes(password: newPass))
            }

            // Update profile row (name/username/avatar_url) in public.profiles
            let nameVal = name?.trimmingCharacters(in: .whitespaces).isEmpty == false ? name?.trimmingCharacters(in: .whitespaces) : nil
            let usernameVal = username?.trimmingCharacters(in: .whitespaces).lowercased().isEmpty == false ? username?.trimmingCharacters(in: .whitespaces).lowercased() : nil

            // Upload avatar image to Supabase Storage if provided
            var avatarUrlString: String?
            var didUploadAvatar = false
            if let imageData = avatarImageData {
                let filePath = "avatars/\(currentAuthUser.id.uuidString).jpg"
                // Upsert (overwrite existing) by uploading with upsert option
                try await supabase.storage
                    .from("avatars")
                    .upload(
                        filePath,
                        data: imageData,
                        options: FileOptions(contentType: "image/jpeg", upsert: true)
                    )
                avatarUrlString = storagePublicURL(bucket: "avatars", path: filePath)
                didUploadAvatar = true
            }

            let hasProfileChanges = nameVal != nil || usernameVal != nil || didUploadAvatar
            if hasProfileChanges {
                let payload = ProfileUpdate(
                    name: nameVal,
                    username: usernameVal,
                    avatar_url: avatarUrlString,
                    includeAvatar: didUploadAvatar
                )
                try await supabase
                    .from("profiles")
                    .update(payload)
                    .eq("id", value: currentAuthUser.id)
                    .execute()
            }

            // Refresh local cached profile
            await refreshCurrentUserProfile()
            return (true, nil)
        } catch {
            debugPrint("updateProfile error:", error)
            return (false, "Unable to update profile. \(error.localizedDescription)")
        }
    }

    /// Call when opening the profile screen so the latest avatar and profile data are shown.
    func refreshCurrentUserProfileIfNeeded() async {
        await refreshCurrentUserProfile()
    }

    private func observeAuthState() async {
        for await state in supabase.auth.authStateChanges {
            if [.initialSession, .signedIn, .signedOut].contains(state.event) {
                if state.session != nil {
                    isAuthenticated = true
                    await ensureProfileExists()
                    await refreshCurrentUserProfile()
                    await refreshGroupsForCurrentUser()
                    if let token = Self.storedDeviceToken { await registerDeviceToken(token) }
                } else {
                    currentUser = nil
                    isAuthenticated = false
                }
            }
        }
    }

    private static let deviceTokenKey = "BlackOut.DeviceToken"
    static var storedDeviceToken: String? { UserDefaults.standard.string(forKey: deviceTokenKey) }

    /// Register device token for push (card-pull notifications). Call when token is received or when user signs in.
    func registerDeviceToken(_ token: String) async {
        guard !token.isEmpty else { return }
        UserDefaults.standard.set(token, forKey: Self.deviceTokenKey)
        guard isAuthenticated, let uid = currentUser?.id else { return }
        do {
            try await supabase
                .from("device_tokens")
                .upsert(DeviceTokenInsert(user_id: uid, token: token, platform: "ios"), onConflict: "user_id,token")
                .execute()
        } catch {
            debugPrint("registerDeviceToken error:", error)
        }
    }

    /// If the DB trigger didn't create a profiles row (e.g. it wasn't active at signup time),
    /// create one now so foreign-key references to profiles(id) work.
    /// Returns `true` if the profile exists (or was just created).
    @discardableResult
    private func ensureProfileExists() async -> Bool {
        do {
            let authUser = try await supabase.auth.session.user
            let uid = authUser.id
            debugPrint("ensureProfileExists: checking for uid=\(uid)")

            // Use upsert with onConflict so it never fails on duplicate
            let meta = authUser.userMetadata
            let name = meta["name"]?.stringValue ?? "User"
            let username = meta["username"]?.stringValue?.lowercased()
                ?? "user_\(uid.uuidString.prefix(8).lowercased())"

            _ = try await supabase
                .from("profiles")
                .upsert(
                    ProfileInsert(id: uid, name: name, username: username),
                    onConflict: "id",
                    ignoreDuplicates: true   // ON CONFLICT (id) DO NOTHING
                )
                .execute()

            // Verify the row actually exists after upsert
            let verify: [ProfileRow] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: uid)
                .limit(1)
                .execute()
                .value

            if verify.isEmpty {
                debugPrint("ensureProfileExists: FAILED — profile still missing after upsert for \(uid)")
                return false
            }
            debugPrint("ensureProfileExists: OK — profile exists for \(uid)")
            return true
        } catch {
            debugPrint("ensureProfileExists error:", error)
            return false
        }
    }

    private func refreshCurrentUserProfile() async {
        do {
            let authUser = try await supabase.auth.session.user
            let profile: ProfileRow = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: authUser.id)
                .single()
                .execute()
                .value

            let user = User(
                id: profile.id,
                name: profile.name,
                username: profile.username,
                email: authUser.email ?? "",
                avatarUrl: profile.avatarUrl
            )
            // cache profile list (at least current user)
            if let idx = users.firstIndex(where: { $0.id == user.id }) {
                users[idx] = user
            } else {
                users.append(user)
            }
            currentUser = user
        } catch {
            debugPrint("refreshCurrentUserProfile error:", error)
        }
    }

    private func refreshGroupsForCurrentUser() async {
        guard isAuthenticated else { return }
        do {
            let authUser = try await supabase.auth.session.user
            let membershipRows: [MembershipRow] = try await supabase
                .from("memberships")
                .select()
                .eq("user_id", value: authUser.id)
                .execute()
                .value

            memberships = membershipRows.map { row in
                Membership(
                    id: row.id,
                    groupId: row.groupId,
                    userId: row.userId,
                    role: row.role.lowercased() == "admin" ? .admin : .member,
                    cardsRemaining: row.cardsRemaining,
                    lastResetAt: row.lastResetAt,
                    lastPetitionAt: row.lastPetitionAt
                )
            }

            let groupIds = Array(Set(membershipRows.map(\.groupId)))
            if groupIds.isEmpty {
                groups = []
                return
            }

            let groupRows: [GroupRow] = try await supabase
                .from("groups")
                .select()
                .in("id", values: groupIds)
                .execute()
                .value

            groups = groupRows.map { row in
                Group(
                    id: row.id,
                    name: row.name,
                    createdByUserId: row.createdByUserId,
                    isPrivate: row.isPrivate,
                    cardsPerPeriod: row.cardsPerPeriod,
                    periodType: PeriodType(rawValue: row.periodType) ?? .month,
                    periodStart: row.periodStart,
                    periodEnd: row.periodEnd,
                    nextResetAt: row.nextResetAt,
                    voteThreshold: .majority,
                    voteDurationHours: row.voteDurationHours,
                    groupPhotoUrl: row.groupPhotoUrl,
                    createdAt: row.createdAt
                )
            }
        } catch {
            // Ignore cancellation (e.g. user ended pull-to-refresh or navigated away)
            let ns = error as NSError
            let isCancelled = ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
                || (error as? URLError)?.code == .cancelled
            if !isCancelled {
                debugPrint("refreshGroupsForCurrentUser error:", error)
            }
        }
    }

    // MARK: - Groups

    /// Creates a group. Returns the group and whether a provided photo failed to upload (e.g. Storage RLS).
    func createGroup(name: String, photoData: Data? = nil) async -> (group: Group?, photoUploadFailed: Bool) {
        guard isAuthenticated, !name.isEmpty else { return (nil, false) }
        do {
            let authUser = try await supabase.auth.session.user
            let uid = authUser.id

            // Guarantee profile row exists before creating a group (FK requirement)
            await ensureProfileExists()

            // Insert the group
            let groupRow: GroupRow = try await supabase
                .from("groups")
                .insert(CreateGroupInsert(name: name, created_by_user_id: uid))
                .select()
                .single()
                .execute()
                .value

            var photoUploadFailed = false
            if let imageData = photoData {
                if await uploadGroupPhoto(groupId: groupRow.id, imageData: imageData) == nil {
                    photoUploadFailed = true
                }
            }

            // Add creator as Admin member.
            _ = try await supabase
                .from("memberships")
                .insert(
                    CreateMembershipInsert(
                        group_id: groupRow.id,
                        user_id: authUser.id,
                        role: "Admin",
                        cards_remaining: groupRow.cardsPerPeriod
                    )
                )
                .execute()

            await refreshGroupsForCurrentUser()
            return (group(for: groupRow.id), photoUploadFailed)
        } catch {
            debugPrint("createGroup error:", error)
            return (nil, false)
        }
    }

    /// Upload or replace a group photo. Updates the group_photo_url column.
    @discardableResult
    func uploadGroupPhoto(groupId: UUID, imageData: Data) async -> String? {
        do {
            let filePath = "groups/\(groupId.uuidString).jpg"
            try await supabase.storage
                .from("media")
                .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))
            let url = storagePublicURL(bucket: "media", path: filePath)

            try await supabase
                .from("groups")
                .update(GroupPhotoUpdate(group_photo_url: url))
                .eq("id", value: groupId)
                .execute()

            await refreshGroupsForCurrentUser()
            return url
        } catch {
            debugPrint("uploadGroupPhoto error:", error)
            return nil
        }
    }

    @discardableResult
    func joinGroup(groupId: UUID) async -> Bool {
        guard isAuthenticated else { return false }
        do {
            let authUser = try await supabase.auth.session.user

            // Fetch group (for cardsPerPeriod) and cache it
            let groupRow: GroupRow = try await supabase
                .from("groups")
                .select()
                .eq("id", value: groupId)
                .single()
                .execute()
                .value

            if groups.first(where: { $0.id == groupRow.id }) == nil {
                groups.append(
                    Group(
                        id: groupRow.id,
                        name: groupRow.name,
                        createdByUserId: groupRow.createdByUserId,
                        isPrivate: groupRow.isPrivate,
                        cardsPerPeriod: groupRow.cardsPerPeriod,
                        periodType: PeriodType(rawValue: groupRow.periodType) ?? .month,
                        periodStart: groupRow.periodStart,
                        periodEnd: groupRow.periodEnd,
                        nextResetAt: groupRow.nextResetAt,
                        voteThreshold: .majority,
                        voteDurationHours: groupRow.voteDurationHours,
                        groupPhotoUrl: groupRow.groupPhotoUrl,
                        createdAt: groupRow.createdAt
                    )
                )
            }

            _ = try await supabase
                .from("memberships")
                .insert(
                    CreateMembershipInsert(
                        group_id: groupId,
                        user_id: authUser.id,
                        role: "Member",
                        cards_remaining: groupRow.cardsPerPeriod
                    )
                )
                .execute()

            await refreshGroupsForCurrentUser()
            await refreshGroupData(groupId: groupId)
            return true
        } catch {
            debugPrint("joinGroup error:", error)
            return false
        }
    }

    func leaveGroup(groupId: UUID) async {
        guard isAuthenticated else { return }
        do {
            let authUser = try await supabase.auth.session.user
            _ = try await supabase
                .from("memberships")
                .delete()
                .eq("group_id", value: groupId)
                .eq("user_id", value: authUser.id)
                .execute()
            await refreshGroupsForCurrentUser()
        } catch {
            debugPrint("leaveGroup error:", error)
        }
    }

    /// Refetch groups (and memberships) from the server. Call when the groups list appears so photos and metadata are up to date.
    func refreshGroups() async {
        await refreshGroupsForCurrentUser()
    }

    func groupsForCurrentUser() -> [GroupInfo] {
        guard let user = currentUser else { return [] }
        let userMemberships = memberships.filter { $0.userId == user.id }
        return userMemberships.compactMap { membership in
            guard let group = groups.first(where: { $0.id == membership.groupId }) else { return nil }
            return GroupInfo(group: group, membership: membership)
        }
    }

    func group(for id: UUID) -> Group? {
        groups.first { $0.id == id }
    }

    // MARK: - Members

    func membersForGroup(_ groupId: UUID) -> [MemberInfo] {
        let groupMemberships = memberships.filter { $0.groupId == groupId }
        return groupMemberships.compactMap { membership in
            guard let user = users.first(where: { $0.id == membership.userId }) else { return nil }
            return MemberInfo(user: user, membership: membership)
        }
    }

    func membershipForCurrentUser(in groupId: UUID) -> Membership? {
        guard let user = currentUser else { return nil }
        return memberships.first { $0.groupId == groupId && $0.userId == user.id }
    }

    func isMember(of groupId: UUID) -> Bool {
        guard let user = currentUser else { return false }
        return memberships.contains { $0.groupId == groupId && $0.userId == user.id }
    }

    func isAdmin(of groupId: UUID) -> Bool {
        guard let user = currentUser else { return false }
        return memberships.contains { $0.groupId == groupId && $0.userId == user.id && $0.role == .admin }
    }

    /// Sends a group invite to the user. They see it in Notifications and can Accept or Decline.
    @discardableResult
    func sendGroupInvite(groupId: UUID, inviteeUserId: UUID) async -> Bool {
        guard isAuthenticated else { return false }
        guard let group = groups.first(where: { $0.id == groupId }) else { return false }
        guard let inviter = currentUser else { return false }
        do {
            // Don't invite if already a member
            let alreadyMember = memberships.contains { $0.groupId == groupId && $0.userId == inviteeUserId }
            guard !alreadyMember else { return false }
            _ = try await supabase
                .from("notifications")
                .insert(
                    NotificationInsert(
                        group_id: groupId,
                        recipient_user_id: inviteeUserId,
                        title: "Group invitation",
                        message: "\(inviter.name) invited you to join \(group.name).",
                        notification_type: "groupInvite",
                        inviter_user_id: inviter.id
                    )
                )
                .execute()
            await refreshNotificationsForCurrentUser()
            return true
        } catch {
            debugPrint("sendGroupInvite error:", error)
            return false
        }
    }

    /// Accept a group invite (add self to group and mark notification read).
    func acceptGroupInvite(notificationId: UUID) async {
        guard isAuthenticated else { return }
        guard let notification = notifications.first(where: { $0.id == notificationId }),
              notification.notificationType == .groupInvite,
              notification.recipientUserId == currentUser?.id else { return }
        let groupId = notification.groupId
        let cardsPerPeriod: Int
        if let group = groups.first(where: { $0.id == groupId }) {
            cardsPerPeriod = group.cardsPerPeriod
        } else {
            guard let row: GroupRow = try? await supabase
                .from("groups")
                .select()
                .eq("id", value: groupId)
                .single()
                .execute()
                .value else { return }
            cardsPerPeriod = row.cardsPerPeriod
        }
        await addMembershipAndMarkInviteRead(groupId: groupId, cardsPerPeriod: cardsPerPeriod, notificationId: notificationId)
    }

    private func addMembershipAndMarkInviteRead(groupId: UUID, cardsPerPeriod: Int, notificationId: UUID) async {
        guard let uid = currentUser?.id else { return }
        do {
            _ = try await supabase
                .from("memberships")
                .insert(CreateMembershipInsert(group_id: groupId, user_id: uid, role: "Member", cards_remaining: cardsPerPeriod))
                .execute()
            await refreshGroupsForCurrentUser()
            await refreshGroupData(groupId: groupId)
            await markNotificationRead(notificationId)
            await refreshNotificationsForCurrentUser()
        } catch {
            debugPrint("acceptGroupInvite error:", error)
        }
    }

    /// Decline a group invite (mark notification read).
    func declineGroupInvite(notificationId: UUID) async {
        guard isAuthenticated else { return }
        guard let notification = notifications.first(where: { $0.id == notificationId }),
              notification.notificationType == .groupInvite,
              notification.recipientUserId == currentUser?.id else { return }
        await markNotificationRead(notificationId)
        await refreshNotificationsForCurrentUser()
    }

    /// Search profiles by name/username, excluding existing group members.
    func searchProfilesNotInGroup(groupId: UUID, query: String, limit: Int = 25) async -> [User] {
        guard isAuthenticated else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        do {
            // Fetch current members so we can exclude them client-side.
            let memberRows: [MemberIdRow] = try await supabase
                .from("memberships")
                .select("user_id")
                .eq("group_id", value: groupId)
                .execute()
                .value
            let memberIds = Set(memberRows.map(\.userId))

            let pattern = "%\(trimmed.lowercased())%"
            let rows: [ProfileRow] = try await supabase
                .from("profiles")
                .select()
                .or("username.ilike.\(pattern),name.ilike.\(pattern)")
                .limit(limit)
                .execute()
                .value

            return rows
                .filter { !memberIds.contains($0.id) }
                .map { User(id: $0.id, name: $0.name, username: $0.username, email: "", avatarUrl: $0.avatarUrl) }
        } catch {
            debugPrint("searchProfilesNotInGroup error:", error)
            return []
        }
    }

    // MARK: - Nights

    func activeNight(for groupId: UUID) -> Night? {
        nights.first { $0.groupId == groupId && $0.status == .active }
    }

    func nightsForGroup(_ groupId: UUID) -> [Night] {
        nights
            .filter { $0.groupId == groupId }
            .sorted { $0.pulledAt > $1.pulledAt }
    }

    func night(for id: UUID) -> Night? {
        nights.first { $0.id == id }
    }

    enum PullCardResult {
        case success(Night)
        case noCardsRemaining
        case activeNightExists
        case notFoundOrDenied
        case error(String)
    }

    /// Pull a blackout card in this group only. Eligibility is per-group: you must have cards in this group and no active night in this group.
    func pullCard(in groupId: UUID) async -> PullCardResult {
        guard isAuthenticated else { return .error("Not signed in.") }
        do {
            let authUser = try await supabase.auth.session.user

            // 1) Membership and cards for this group only
            let membership: MembershipRow
            do {
                membership = try await supabase
                    .from("memberships")
                    .select()
                    .eq("group_id", value: groupId)
                    .eq("user_id", value: authUser.id)
                    .single()
                    .execute()
                    .value
            } catch {
                debugPrint("pullCard membership fetch error:", error)
                return .notFoundOrDenied
            }
            guard membership.cardsRemaining > 0 else { return .noCardsRemaining }

            // 2) No active night in this group only
            let active: [NightRow] = try await supabase
                .from("nights")
                .select()
                .eq("group_id", value: groupId)
                .eq("status", value: "Active")
                .limit(1)
                .execute()
                .value
            guard active.isEmpty else { return .activeNightExists }

            // 3) Decrement cards for this membership only
            _ = try await supabase
                .from("memberships")
                .update(MembershipCardsUpdate(cards_remaining: membership.cardsRemaining - 1))
                .eq("id", value: membership.id)
                .execute()

            // 4) Create night in this group
            let nightRow: NightRow = try await supabase
                .from("nights")
                .insert(NightInsert(group_id: groupId, pulled_by_user_id: authUser.id, status: "Active"))
                .select()
                .single()
                .execute()
                .value

            // 5) Notify members of this group only
            let memberIds: [MemberIdRow] = try await supabase
                .from("memberships")
                .select("user_id")
                .eq("group_id", value: groupId)
                .execute()
                .value

            let pullerName = currentUser?.name ?? "Someone"
            let inserts = memberIds.map { member in
                NotificationInsert(
                    group_id: groupId,
                    recipient_user_id: member.userId,
                    title: "BLACKOUT CARD PULLED",
                    message: "\(pullerName) PULLED THEIR BLACKOUT CARD!",
                    notification_type: "cardPulled"
                )
            }
            if !inserts.isEmpty {
                _ = try await supabase.from("notifications").insert(inserts).execute()
            }

            // Lyft-style: trigger push to all group members (Edge Function sends APNs; cron repeats until they open app)
            Task { await triggerCardPullPush(groupId: groupId, pullerName: pullerName) }

            await refreshGroupData(groupId: groupId)
            await refreshNotificationsForCurrentUser()
            if let night = night(for: nightRow.id) {
                return .success(night)
            }
            return .error("Card pulled but could not load night.")
        } catch {
            debugPrint("pullCard error:", error)
            return .error(error.localizedDescription)
        }
    }

    func closeNight(_ nightId: UUID) async {
        do {
            _ = try await supabase
                .from("nights")
                .update(NightStatusUpdate(status: "Closed"))
                .eq("id", value: nightId)
                .execute()
            if let night = night(for: nightId) {
                await refreshGroupData(groupId: night.groupId)
            }
        } catch {
            debugPrint("closeNight error:", error)
        }
    }

    /// Loads memberships + member profiles + nights + media + vote cases/votes for a single group.
    func refreshGroupData(groupId: UUID) async {
        guard isAuthenticated else { return }
        do {
            let membershipRows: [MembershipRow] = try await supabase
                .from("memberships")
                .select()
                .eq("group_id", value: groupId)
                .execute()
                .value

            // Replace memberships for this group
            memberships.removeAll { $0.groupId == groupId }
            memberships.append(contentsOf: membershipRows.map {
                Membership(
                    id: $0.id,
                    groupId: $0.groupId,
                    userId: $0.userId,
                    role: $0.role.lowercased() == "admin" ? .admin : .member,
                    cardsRemaining: $0.cardsRemaining,
                    lastResetAt: $0.lastResetAt,
                    lastPetitionAt: $0.lastPetitionAt
                )
            })

            let memberUserIds = Array(Set(membershipRows.map(\.userId)))
            if !memberUserIds.isEmpty {
                let profiles: [ProfileRow] = try await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: memberUserIds)
                    .execute()
                    .value

                for profile in profiles {
                    let u = User(id: profile.id, name: profile.name, username: profile.username, email: "", avatarUrl: profile.avatarUrl)
                    if let idx = users.firstIndex(where: { $0.id == u.id }) { users[idx] = u } else { users.append(u) }
                }
            }

            let nightRows: [NightRow] = try await supabase
                .from("nights")
                .select()
                .eq("group_id", value: groupId)
                .order("pulled_at", ascending: false)
                .execute()
                .value

            nights.removeAll { $0.groupId == groupId }
            nights.append(contentsOf: nightRows.map {
                Night(
                    id: $0.id,
                    groupId: $0.groupId,
                    pulledByUserId: $0.pulledByUserId,
                    pulledAt: $0.pulledAt,
                    status: $0.status == "Closed" ? .closed : .active
                )
            })

            let mediaRows: [MediaRow] = try await supabase
                .from("media")
                .select()
                .eq("group_id", value: groupId)
                .order("created_at", ascending: false)
                .execute()
                .value

            mediaItems.removeAll { $0.groupId == groupId }
            mediaItems.append(contentsOf: mediaRows.map { row in
                let resolvedURL: String?
                if let raw = row.url, !raw.isEmpty {
                    resolvedURL = raw.hasPrefix("http") ? raw : storagePublicURL(bucket: "media", path: raw)
                } else {
                    resolvedURL = nil
                }
                return MediaItem(
                    id: row.id,
                    nightId: row.nightId,
                    groupId: row.groupId,
                    uploaderUserId: row.uploaderUserId,
                    mediaType: row.mediaType == "Video" ? .video : .image,
                    localImageData: nil,
                    url: resolvedURL,
                    caption: row.caption,
                    createdAt: row.createdAt
                )
            })

            let vcRows: [VoteCaseRow] = try await supabase
                .from("vote_cases")
                .select()
                .eq("group_id", value: groupId)
                .order("opens_at", ascending: false)
                .execute()
                .value

            voteCases.removeAll { $0.groupId == groupId }
            voteCases.append(contentsOf: vcRows.map {
                VoteCase(
                    id: $0.id,
                    groupId: $0.groupId,
                    nightId: $0.nightId,
                    caseType: $0.caseType == "Petition" ? .petition : .failure,
                    targetUserId: $0.targetUserId,
                    initiatedByUserId: $0.initiatedByUserId,
                    opensAt: $0.opensAt,
                    closesAt: $0.closesAt,
                    status: $0.status == "Resolved" ? .resolved : .open,
                    result: ($0.result == "Pass") ? .pass : (($0.result == "Fail") ? .fail : nil),
                    createdAt: $0.createdAt
                )
            })

            let openCaseIds = vcRows.map(\.id)
            if !openCaseIds.isEmpty {
                let voteRows: [VoteRow] = try await supabase
                    .from("votes")
                    .select()
                    .in("vote_case_id", values: openCaseIds)
                    .execute()
                    .value
                votes.removeAll { openCaseIds.contains($0.voteCaseId) }
                votes.append(contentsOf: voteRows.map {
                    Vote(
                        id: $0.id,
                        voteCaseId: $0.voteCaseId,
                        voterUserId: $0.voterUserId,
                        value: $0.value == "No" ? .no : .yes,
                        createdAt: $0.createdAt
                    )
                })
            }
        } catch {
            debugPrint("refreshGroupData error:", error)
        }
    }

    func refreshNotificationsForCurrentUser(limit: Int = 100) async {
        guard isAuthenticated else { return }
        do {
            let authUser = try await supabase.auth.session.user
            let rows: [NotificationRow] = try await supabase
                .from("notifications")
                .select()
                .eq("recipient_user_id", value: authUser.id)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            notifications = rows.map {
                AppNotification(
                    id: $0.id,
                    groupId: $0.groupId,
                    recipientUserId: $0.recipientUserId,
                    title: $0.title,
                    message: $0.message,
                    notificationType: NotificationType(rawValue: $0.notificationType) ?? .cardPulled,
                    createdAt: $0.createdAt,
                    isRead: $0.isRead,
                    inviterUserId: $0.inviterUserId
                )
            }
        } catch {
            debugPrint("refreshNotificationsForCurrentUser error:", error)
        }
    }

    // MARK: - Media

    @discardableResult
    func addMedia(nightId: UUID, groupId: UUID, mediaType: MediaType, imageData: Data?, caption: String?) async -> MediaItem? {
        guard isAuthenticated else { return nil }
        guard mediaType == .image else { return nil } // MVP: images only
        guard let data = imageData else { return nil }

        do {
            let authUser = try await supabase.auth.session.user
            let filePath = "groups/\(groupId.uuidString)/nights/\(nightId.uuidString)/\(UUID().uuidString).jpg"

            try await supabase.storage
                .from("media")
                .upload(
                    filePath,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg")
                )

            let row: MediaRow = try await supabase
                .from("media")
                .insert(
                    MediaInsert(
                        night_id: nightId,
                        group_id: groupId,
                        uploader_user_id: authUser.id,
                        media_type: "Image",
                        url: filePath,
                        caption: caption
                    )
                )
                .select()
                .single()
                .execute()
                .value

            await refreshGroupData(groupId: groupId)
            return mediaItems.first(where: { $0.id == row.id })
        } catch {
            debugPrint("addMedia error:", error)
            return nil
        }
    }

    func mediaForNight(_ nightId: UUID) -> [MediaItem] {
        mediaItems
            .filter { $0.nightId == nightId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Vote Cases

    @discardableResult
    func startFailureVote(groupId: UUID, nightId: UUID, targetUserId: UUID) async -> VoteCase? {
        guard isAuthenticated else { return nil }
        guard let user = currentUser else { return nil }
        guard let night = nights.first(where: { $0.id == nightId }) else { return nil }
        guard night.pulledByUserId == user.id else { return nil }
        guard let group = groups.first(where: { $0.id == groupId }) else { return nil }

        do {
            // Prevent duplicates
            let existing: [VoteCaseRow] = try await supabase
                .from("vote_cases")
                .select()
                .eq("group_id", value: groupId)
                .eq("night_id", value: nightId)
                .eq("target_user_id", value: targetUserId)
                .eq("case_type", value: "Failure")
                .eq("status", value: "Open")
                .limit(1)
                .execute()
                .value
            guard existing.isEmpty else { return nil }

            let closesAt = Date().addingTimeInterval(Double(group.voteDurationHours) * 3600)

            let row: VoteCaseRow = try await supabase
                .from("vote_cases")
                .insert(
                    VoteCaseInsert(
                        group_id: groupId,
                        night_id: nightId,
                        case_type: "Failure",
                        target_user_id: targetUserId,
                        initiated_by_user_id: user.id,
                        closes_at: closesAt,
                        status: "Open"
                    )
                )
                .select()
                .single()
                .execute()
                .value

            // Notify group members
            let memberIds: [MemberIdRow] = try await supabase
                .from("memberships")
                .select("user_id")
                .eq("group_id", value: groupId)
                .execute()
                .value

            let targetName = userName(for: targetUserId)
            let inserts = memberIds.map {
                NotificationInsert(
                    group_id: groupId,
                    recipient_user_id: $0.userId,
                    title: "Vote Started",
                    message: "A vote has been started against \(targetName) for not showing up",
                    notification_type: "voteStarted"
                )
            }
            if !inserts.isEmpty {
                _ = try await supabase.from("notifications").insert(inserts).execute()
            }

            await refreshGroupData(groupId: groupId)
            await refreshNotificationsForCurrentUser()
            return voteCase(for: row.id)
        } catch {
            debugPrint("startFailureVote error:", error)
            return nil
        }
    }

    @discardableResult
    func startPetition(groupId: UUID) async -> VoteCase? {
        guard isAuthenticated else { return nil }
        guard let user = currentUser else { return nil }
        guard let membership = memberships.first(where: { $0.groupId == groupId && $0.userId == user.id }) else { return nil }
        guard membership.cardsRemaining == 0 else { return nil }
        guard let group = groups.first(where: { $0.id == groupId }) else { return nil }

        do {
            let existing: [VoteCaseRow] = try await supabase
                .from("vote_cases")
                .select()
                .eq("group_id", value: groupId)
                .eq("target_user_id", value: user.id)
                .eq("case_type", value: "Petition")
                .eq("status", value: "Open")
                .limit(1)
                .execute()
                .value
            guard existing.isEmpty else { return nil }

            let closesAt = Date().addingTimeInterval(Double(group.voteDurationHours) * 3600)

            let row: VoteCaseRow = try await supabase
                .from("vote_cases")
                .insert(
                    VoteCaseInsert(
                        group_id: groupId,
                        night_id: nil,
                        case_type: "Petition",
                        target_user_id: user.id,
                        initiated_by_user_id: user.id,
                        closes_at: closesAt,
                        status: "Open"
                    )
                )
                .select()
                .single()
                .execute()
                .value

            _ = try await supabase
                .from("memberships")
                .update(MembershipLastPetitionUpdate(last_petition_at: Date()))
                .eq("id", value: membership.id)
                .execute()

            // Notify group members
            let memberIds: [MemberIdRow] = try await supabase
                .from("memberships")
                .select("user_id")
                .eq("group_id", value: groupId)
                .execute()
                .value

            let inserts = memberIds.map {
                NotificationInsert(
                    group_id: groupId,
                    recipient_user_id: $0.userId,
                    title: "Petition to Restore",
                    message: "\(user.name) is petitioning to restore their Blackout Card",
                    notification_type: "petitionStarted"
                )
            }
            if !inserts.isEmpty {
                _ = try await supabase.from("notifications").insert(inserts).execute()
            }

            await refreshGroupData(groupId: groupId)
            await refreshNotificationsForCurrentUser()
            return voteCase(for: row.id)
        } catch {
            debugPrint("startPetition error:", error)
            return nil
        }
    }

    @discardableResult
    func castVote(voteCaseId: UUID, value: VoteValue) async -> Vote? {
        guard isAuthenticated else { return nil }
        guard let user = currentUser else { return nil }
        guard let vc = voteCases.first(where: { $0.id == voteCaseId }) else { return nil }
        guard vc.status == .open else { return nil }
        guard Date() < vc.closesAt else { return nil }
        guard !votes.contains(where: { $0.voteCaseId == voteCaseId && $0.voterUserId == user.id }) else { return nil }

        do {
            let row: VoteRow = try await supabase
                .from("votes")
                .insert(VoteInsert(vote_case_id: voteCaseId, voter_user_id: user.id, value: value.rawValue))
                .select()
                .single()
                .execute()
                .value

            await refreshGroupData(groupId: vc.groupId)
            return votes.first(where: { $0.id == row.id })
        } catch {
            debugPrint("castVote error:", error)
            return nil
        }
    }

    func hasCurrentUserVoted(on voteCaseId: UUID) -> Bool {
        guard let user = currentUser else { return false }
        return votes.contains { $0.voteCaseId == voteCaseId && $0.voterUserId == user.id }
    }

    func votesForCase(_ voteCaseId: UUID) -> [Vote] {
        votes.filter { $0.voteCaseId == voteCaseId }
    }

    func voteCasesForNight(_ nightId: UUID) -> [VoteCase] {
        voteCases.filter { $0.nightId == nightId }
    }

    func openVoteCasesForGroup(_ groupId: UUID) -> [VoteCase] {
        voteCases.filter { $0.groupId == groupId && $0.status == .open }
    }

    func voteCase(for id: UUID) -> VoteCase? {
        voteCases.first { $0.id == id }
    }

    func canPetition(groupId: UUID) -> Bool {
        guard let user = currentUser else { return false }
        guard let membership = memberships.first(where: {
            $0.groupId == groupId && $0.userId == user.id
        }) else { return false }
        guard membership.cardsRemaining == 0 else { return false }

        let existingPetition = voteCases.first {
            $0.groupId == groupId &&
            $0.targetUserId == user.id &&
            $0.caseType == .petition &&
            ($0.createdAt > (membership.lastResetAt ?? .distantPast))
        }
        return existingPetition == nil
    }

    // MARK: - Resolve Expired Votes

    func resolveExpiredVoteCases() {
        guard isAuthenticated else { return }
        Task {
            do {
                _ = try await supabase.rpc("resolve_expired_vote_cases").execute()

                // Refresh all groups the current user belongs to (keeps UI consistent).
                let groupIds = Set(memberships
                    .filter { $0.userId == currentUser?.id }
                    .map(\.groupId)
                )
                for gid in groupIds {
                    await refreshGroupData(groupId: gid)
                }
                await refreshNotificationsForCurrentUser()
            } catch {
                debugPrint("resolveExpiredVoteCases rpc error:", error)
            }
        }
    }

    // MARK: - Admin Settings

    func updateGroupSettings(
        groupId: UUID,
        cardsPerPeriod: Int?,
        periodType: PeriodType?,
        periodStart: Date?,
        periodEnd: Date?
    ) async {
        guard isAuthenticated else { return }
        do {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            let payload = GroupSettingsUpdate(
                cards_per_period: cardsPerPeriod,
                period_type: periodType?.rawValue,
                period_start: periodStart.map { fmt.string(from: $0) },
                period_end: periodEnd.map { fmt.string(from: $0) }
            )
            if cardsPerPeriod != nil || periodType != nil || periodStart != nil || periodEnd != nil {
                _ = try await supabase
                    .from("groups")
                    .update(payload)
                    .eq("id", value: groupId)
                    .execute()
            }
            await refreshGroupsForCurrentUser()
        } catch {
            debugPrint("updateGroupSettings error:", error)
        }
    }

    func resetPeriod(groupId: UUID) async {
        guard isAuthenticated else { return }
        guard let group = groups.first(where: { $0.id == groupId }) else { return }
        do {
            // Reset all memberships for this group
            let resetFmt = ISO8601DateFormatter()
            resetFmt.formatOptions = [.withInternetDateTime]
            _ = try await supabase
                .from("memberships")
                .update(MembershipResetUpdate(
                    cards_remaining: group.cardsPerPeriod,
                    last_reset_at: resetFmt.string(from: Date()),
                    last_petition_at: nil
                ))
                .eq("group_id", value: groupId)
                .execute()

            // Close active night if any
            _ = try await supabase
                .from("nights")
                .update(NightStatusUpdate(status: "Closed"))
                .eq("group_id", value: groupId)
                .eq("status", value: "Active")
                .execute()

            // Notify all members
            let memberIds: [MemberIdRow] = try await supabase
                .from("memberships")
                .select("user_id")
                .eq("group_id", value: groupId)
                .execute()
                .value

            let inserts = memberIds.map {
                NotificationInsert(
                    group_id: groupId,
                    recipient_user_id: $0.userId,
                    title: "Period Reset",
                    message: "The period has been reset. Your cards have been restored!",
                    notification_type: "periodReset"
                )
            }
            if !inserts.isEmpty {
                _ = try await supabase.from("notifications").insert(inserts).execute()
            }

            await refreshGroupData(groupId: groupId)
            await refreshNotificationsForCurrentUser()
        } catch {
            debugPrint("resetPeriod error:", error)
        }
    }

    // MARK: - Notifications

    func notificationsForCurrentUser() -> [AppNotification] {
        guard let user = currentUser else { return [] }
        return notifications
            .filter { $0.recipientUserId == user.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func markNotificationRead(_ id: UUID) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].isRead = true
        }
        guard isAuthenticated else { return }
        Task {
            do {
                _ = try await supabase
                    .from("notifications")
                    .update(NotificationReadUpdate(is_read: true))
                    .eq("id", value: id)
                    .execute()
                await refreshNotificationsForCurrentUser()
            } catch {
                debugPrint("markNotificationRead error:", error)
            }
        }
    }

    func markAllNotificationsRead() {
        guard let user = currentUser else { return }
        for i in notifications.indices where notifications[i].recipientUserId == user.id {
            notifications[i].isRead = true
        }
        guard isAuthenticated else { return }
        Task {
            do {
                let authUser = try await supabase.auth.session.user
                _ = try await supabase
                    .from("notifications")
                    .update(NotificationReadUpdate(is_read: true))
                    .eq("recipient_user_id", value: authUser.id)
                    .execute()
                await refreshNotificationsForCurrentUser()
            } catch {
                debugPrint("markAllNotificationsRead error:", error)
            }
        }
    }

    func unreadCount() -> Int {
        guard let user = currentUser else { return 0 }
        return notifications.filter { $0.recipientUserId == user.id && !$0.isRead }.count
    }

    /// Number of unread "card pulled" notifications for the current user (used for in-app vibration).
    var unreadCardPulledCount: Int {
        guard let user = currentUser else { return 0 }
        return notifications.filter {
            $0.recipientUserId == user.id && !$0.isRead && $0.notificationType == .cardPulled
        }.count
    }

    /// Calls the Edge Function to send push notifications to all group members (Lyft-style). Fire-and-forget.
    private func triggerCardPullPush(groupId: UUID, pullerName: String) async {
        let base = SupabaseConfig.projectURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/functions/v1/send-card-pull-push") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["groupId": groupId.uuidString, "pullerName": pullerName]
        request.httpBody = try? JSONEncoder().encode(body)
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Banner

    private func showBanner(_ notification: AppNotification) {
        guard notification.recipientUserId == currentUser?.id else { return }
        bannerNotification = notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            if self?.bannerNotification?.id == notification.id {
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.bannerNotification = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private func storagePublicURL(bucket: String, path: String) -> String {
        let base = SupabaseConfig.projectURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return "\(base)/storage/v1/object/public/\(bucket)/\(cleanPath)"
    }

    func userName(for userId: UUID) -> String {
        users.first { $0.id == userId }?.name ?? "Unknown"
    }

    func user(for userId: UUID) -> User? {
        users.first { $0.id == userId }
    }

    // MARK: - Vote Resolution Timer

    private func startVoteResolutionTimer() {
        timerCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.resolveExpiredVoteCases()
            }
    }

}
