import Foundation
import Combine
import SwiftUI

/// Central in-memory data store. Manages all app state and business logic.
/// Designed to be replaced with a real backend/database layer later.
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

    private init() {
        startVoteResolutionTimer()
    }

    // MARK: - Auth

    @discardableResult
    func signUp(name: String, username: String, email: String, password: String) -> Bool {
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty, !name.isEmpty, !trimmedUsername.isEmpty else { return false }
        guard !users.contains(where: { $0.email.lowercased() == trimmedEmail }) else { return false }
        guard !users.contains(where: { $0.username.lowercased() == trimmedUsername }) else { return false }

        let user = User(name: name, username: trimmedUsername, email: trimmedEmail, password: password)
        users.append(user)
        currentUser = user
        isAuthenticated = true
        return true
    }

    @discardableResult
    func login(email: String, password: String) -> Bool {
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard let user = users.first(where: { $0.email.lowercased() == trimmedEmail }) else { return false }
        if let storedPassword = user.password, storedPassword != password { return false }
        currentUser = user
        isAuthenticated = true
        return true
    }

    func logout() {
        currentUser = nil
        isAuthenticated = false
    }

    /// Update current user's profile. Pass currentPassword to change email or password; must match stored password.
    @discardableResult
    func updateProfile(avatarImageData: Data?, name: String?, username: String?, email: String?, newPassword: String?, currentPassword: String?) -> (success: Bool, error: String?) {
        guard let user = currentUser, let idx = users.firstIndex(where: { $0.id == user.id }) else {
            return (false, "Not signed in.")
        }
        if let n = name, !n.trimmingCharacters(in: .whitespaces).isEmpty {
            users[idx].name = n.trimmingCharacters(in: .whitespaces)
        }
        if username != nil {
            let trimmed = username!.trimmingCharacters(in: .whitespaces).lowercased()
            guard !trimmed.isEmpty else { return (false, "Username cannot be empty.") }
            if users.contains(where: { $0.username.lowercased() == trimmed && $0.id != user.id }) {
                return (false, "That username is already taken.")
            }
            users[idx].username = trimmed
        }
        if email != nil {
            let trimmed = email!.lowercased().trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return (false, "Email cannot be empty.") }
            guard trimmed.contains("@"), trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).count == 2 else {
                return (false, "Please enter a valid email address (must contain @).")
            }
            guard let cp = currentPassword, cp == users[idx].password else {
                return (false, "Enter your current password to change email.")
            }
            if users.contains(where: { $0.email.lowercased() == trimmed && $0.id != user.id }) {
                return (false, "That email is already in use.")
            }
            users[idx].email = trimmed
        }
        if let newPass = newPassword {
            guard !newPass.isEmpty else { return (false, "New password cannot be empty.") }
            guard newPass.count >= 6 else { return (false, "New password must be at least 6 characters.") }
            guard let cp = currentPassword, cp == users[idx].password else {
                return (false, "Enter your current password to change password.")
            }
            users[idx].password = newPass
        }
        if let data = avatarImageData {
            users[idx].avatarImageData = data
        }
        currentUser = users[idx]
        return (true, nil)
    }

    // MARK: - Groups

    @discardableResult
    func createGroup(name: String) -> Group? {
        guard let user = currentUser, !name.isEmpty else { return nil }

        let group = Group(name: name, createdByUserId: user.id)
        groups.append(group)

        let membership = Membership(
            groupId: group.id,
            userId: user.id,
            role: .admin,
            cardsRemaining: group.cardsPerPeriod
        )
        memberships.append(membership)
        return group
    }

    @discardableResult
    func joinGroup(groupId: UUID) -> Bool {
        guard let user = currentUser else { return false }
        guard let group = groups.first(where: { $0.id == groupId }) else { return false }
        guard !memberships.contains(where: { $0.groupId == groupId && $0.userId == user.id }) else { return false }

        let membership = Membership(
            groupId: groupId,
            userId: user.id,
            role: .member,
            cardsRemaining: group.cardsPerPeriod
        )
        memberships.append(membership)
        return true
    }

    func leaveGroup(groupId: UUID) {
        guard let user = currentUser else { return }
        memberships.removeAll { $0.groupId == groupId && $0.userId == user.id }
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

    @discardableResult
    func addMemberToGroup(groupId: UUID, userId: UUID) -> Bool {
        guard let group = groups.first(where: { $0.id == groupId }) else { return false }
        guard !memberships.contains(where: { $0.groupId == groupId && $0.userId == userId }) else { return false }

        let membership = Membership(
            groupId: groupId,
            userId: userId,
            cardsRemaining: group.cardsPerPeriod
        )
        memberships.append(membership)
        return true
    }

    /// Users who are not yet members of the group (for "Add member" search).
    func usersNotInGroup(_ groupId: UUID) -> [User] {
        let memberUserIds = Set(memberships.filter { $0.groupId == groupId }.map(\.userId))
        return users.filter { !memberUserIds.contains($0.id) }
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

    @discardableResult
    func pullCard(in groupId: UUID) -> Night? {
        guard let user = currentUser else { return nil }
        guard let memberIdx = memberships.firstIndex(where: {
            $0.groupId == groupId && $0.userId == user.id
        }) else { return nil }
        guard memberships[memberIdx].cardsRemaining > 0 else { return nil }
        guard activeNight(for: groupId) == nil else { return nil }

        // Decrement cards
        memberships[memberIdx].cardsRemaining -= 1

        // Create night
        let night = Night(groupId: groupId, pulledByUserId: user.id)
        nights.append(night)

        // Notify all group members
        let groupMembers = memberships.filter { $0.groupId == groupId }
        for member in groupMembers {
            let notification = AppNotification(
                groupId: groupId,
                recipientUserId: member.userId,
                title: "BLACKOUT CARD PULLED",
                message: "\(user.name) PULLED THEIR BLACKOUT CARD!",
                notificationType: .cardPulled
            )
            notifications.append(notification)
            if member.userId != user.id {
                showBanner(notification)
            }
        }

        return night
    }

    func closeNight(_ nightId: UUID) {
        guard let idx = nights.firstIndex(where: { $0.id == nightId }) else { return }
        nights[idx].status = .closed
    }

    // MARK: - Media

    @discardableResult
    func addMedia(nightId: UUID, groupId: UUID, mediaType: MediaType, imageData: Data?, caption: String?) -> MediaItem? {
        guard let user = currentUser else { return nil }
        let item = MediaItem(
            nightId: nightId,
            groupId: groupId,
            uploaderUserId: user.id,
            mediaType: mediaType,
            localImageData: imageData,
            caption: caption
        )
        mediaItems.append(item)
        return item
    }

    func mediaForNight(_ nightId: UUID) -> [MediaItem] {
        mediaItems
            .filter { $0.nightId == nightId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Vote Cases

    @discardableResult
    func startFailureVote(groupId: UUID, nightId: UUID, targetUserId: UUID) -> VoteCase? {
        guard let user = currentUser else { return nil }
        guard let night = nights.first(where: { $0.id == nightId }) else { return nil }
        guard night.pulledByUserId == user.id else { return nil }
        guard let group = groups.first(where: { $0.id == groupId }) else { return nil }

        // Prevent duplicate open failure votes against the same person in the same night
        let existing = voteCases.first {
            $0.nightId == nightId && $0.targetUserId == targetUserId &&
            $0.caseType == .failure && $0.status == .open
        }
        guard existing == nil else { return nil }

        let voteCase = VoteCase(
            groupId: groupId,
            nightId: nightId,
            caseType: .failure,
            targetUserId: targetUserId,
            initiatedByUserId: user.id,
            voteDurationHours: group.voteDurationHours
        )
        voteCases.append(voteCase)

        // Notify group
        let targetName = userName(for: targetUserId)
        let groupMembers = memberships.filter { $0.groupId == groupId }
        for member in groupMembers {
            let notification = AppNotification(
                groupId: groupId,
                recipientUserId: member.userId,
                title: "Vote Started",
                message: "A vote has been started against \(targetName) for not showing up",
                notificationType: .voteStarted
            )
            notifications.append(notification)
            showBanner(notification)
        }

        return voteCase
    }

    @discardableResult
    func startPetition(groupId: UUID) -> VoteCase? {
        guard let user = currentUser else { return nil }
        guard let membership = memberships.first(where: {
            $0.groupId == groupId && $0.userId == user.id
        }) else { return nil }
        guard membership.cardsRemaining == 0 else { return nil }

        // Limit: 1 petition per period per user per group
        let existingPetition = voteCases.first {
            $0.groupId == groupId &&
            $0.targetUserId == user.id &&
            $0.caseType == .petition &&
            ($0.createdAt > (membership.lastResetAt ?? .distantPast))
        }
        guard existingPetition == nil else { return nil }

        guard let group = groups.first(where: { $0.id == groupId }) else { return nil }

        let voteCase = VoteCase(
            groupId: groupId,
            caseType: .petition,
            targetUserId: user.id,
            initiatedByUserId: user.id,
            voteDurationHours: group.voteDurationHours
        )
        voteCases.append(voteCase)

        // Update lastPetitionAt
        if let idx = memberships.firstIndex(where: {
            $0.groupId == groupId && $0.userId == user.id
        }) {
            memberships[idx].lastPetitionAt = Date()
        }

        // Notify group
        let groupMembers = memberships.filter { $0.groupId == groupId }
        for member in groupMembers {
            let notification = AppNotification(
                groupId: groupId,
                recipientUserId: member.userId,
                title: "Petition to Restore",
                message: "\(user.name) is petitioning to restore their Blackout Card",
                notificationType: .petitionStarted
            )
            notifications.append(notification)
            showBanner(notification)
        }

        return voteCase
    }

    @discardableResult
    func castVote(voteCaseId: UUID, value: VoteValue) -> Vote? {
        guard let user = currentUser else { return nil }
        guard let vc = voteCases.first(where: { $0.id == voteCaseId }) else { return nil }
        guard vc.status == .open else { return nil }
        guard Date() < vc.closesAt else { return nil }

        // One vote per user per case
        guard !votes.contains(where: {
            $0.voteCaseId == voteCaseId && $0.voterUserId == user.id
        }) else { return nil }

        let vote = Vote(voteCaseId: voteCaseId, voterUserId: user.id, value: value)
        votes.append(vote)
        return vote
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
        let now = Date()
        for i in voteCases.indices {
            guard voteCases[i].status == .open, now >= voteCases[i].closesAt else { continue }

            let caseVotes = votes.filter { $0.voteCaseId == voteCases[i].id }
            let yesCount = caseVotes.filter { $0.value == .yes }.count
            let noCount = caseVotes.filter { $0.value == .no }.count

            // Majority of votes cast; ties and no votes = fail
            let passed = yesCount > noCount && (yesCount + noCount) > 0

            voteCases[i].status = .resolved
            voteCases[i].result = passed ? .pass : .fail

            if passed {
                if voteCases[i].caseType == .failure {
                    // Penalty: target loses card for this period
                    if let idx = memberships.firstIndex(where: {
                        $0.groupId == voteCases[i].groupId && $0.userId == voteCases[i].targetUserId
                    }) {
                        memberships[idx].cardsRemaining = 0
                    }
                } else if voteCases[i].caseType == .petition {
                    // Restore card
                    if let idx = memberships.firstIndex(where: {
                        $0.groupId == voteCases[i].groupId && $0.userId == voteCases[i].targetUserId
                    }) {
                        memberships[idx].cardsRemaining = 1
                    }
                }
            }

            // Notify group
            let groupMembers = memberships.filter { $0.groupId == voteCases[i].groupId }
            let targetName = userName(for: voteCases[i].targetUserId)
            let resultText = passed ? "passed" : "failed"
            let typeText = voteCases[i].caseType == .failure ? "Vote" : "Petition"

            for member in groupMembers {
                let notification = AppNotification(
                    groupId: voteCases[i].groupId,
                    recipientUserId: member.userId,
                    title: "\(typeText) Resolved",
                    message: "The \(typeText.lowercased()) regarding \(targetName) has \(resultText)",
                    notificationType: voteCases[i].caseType == .failure ? .voteResolved : .petitionResolved
                )
                notifications.append(notification)
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
    ) {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return }
        if let cpp = cardsPerPeriod { groups[idx].cardsPerPeriod = cpp }
        if let pt = periodType { groups[idx].periodType = pt }
        groups[idx].periodStart = periodStart
        groups[idx].periodEnd = periodEnd
    }

    func resetPeriod(groupId: UUID) {
        guard let group = groups.first(where: { $0.id == groupId }) else { return }
        let now = Date()

        for i in memberships.indices {
            if memberships[i].groupId == groupId {
                memberships[i].cardsRemaining = group.cardsPerPeriod
                memberships[i].lastResetAt = now
                memberships[i].lastPetitionAt = nil
            }
        }

        // Close active night if any
        if let nightIdx = nights.firstIndex(where: { $0.groupId == groupId && $0.status == .active }) {
            nights[nightIdx].status = .closed
        }

        // Notify all members
        let groupMembers = memberships.filter { $0.groupId == groupId }
        for member in groupMembers {
            let notification = AppNotification(
                groupId: groupId,
                recipientUserId: member.userId,
                title: "Period Reset",
                message: "The period has been reset. Your cards have been restored!",
                notificationType: .periodReset
            )
            notifications.append(notification)
            showBanner(notification)
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
    }

    func markAllNotificationsRead() {
        guard let user = currentUser else { return }
        for i in notifications.indices where notifications[i].recipientUserId == user.id {
            notifications[i].isRead = true
        }
    }

    func unreadCount() -> Int {
        guard let user = currentUser else { return 0 }
        return notifications.filter { $0.recipientUserId == user.id && !$0.isRead }.count
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

    // MARK: - Seed Demo Data (for development/testing)

    func seedDemoData() {
        let alice = User(name: "Alice Johnson", username: "alice", email: "alice@demo.com", password: "password")
        let bob = User(name: "Bob Smith", username: "bob", email: "bob@demo.com", password: "password")
        let charlie = User(name: "Charlie Davis", username: "charlie", email: "charlie@demo.com", password: "password")
        let diana = User(name: "Diana Lee", username: "diana", email: "diana@demo.com", password: "password")
        users = [alice, bob, charlie, diana]

        let group1 = Group(name: "Weekend Crew", createdByUserId: alice.id, cardsPerPeriod: 2)
        let group2 = Group(name: "College Friends", createdByUserId: bob.id)
        groups = [group1, group2]

        memberships = [
            Membership(groupId: group1.id, userId: alice.id, role: .admin, cardsRemaining: 2),
            Membership(groupId: group1.id, userId: bob.id, cardsRemaining: 2),
            Membership(groupId: group1.id, userId: charlie.id, cardsRemaining: 2),
            Membership(groupId: group1.id, userId: diana.id, cardsRemaining: 2),
            Membership(groupId: group2.id, userId: bob.id, role: .admin, cardsRemaining: 1),
            Membership(groupId: group2.id, userId: alice.id, cardsRemaining: 1),
            Membership(groupId: group2.id, userId: charlie.id, cardsRemaining: 1),
        ]
    }
}
