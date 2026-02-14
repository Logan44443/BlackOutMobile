import SwiftUI
import PhotosUI

struct GroupHomeView: View {
    let groupId: UUID
    @StateObject private var viewModel: GroupHomeViewModel
    @State private var showAdminSettings = false
    @State private var showPetition = false
    @State private var showAddMember = false
    @State private var showInviteLinkCopied = false
    @State private var navigateToNight: Night?
    @State private var pullCardDragOffset: CGFloat = 0
    @State private var groupPhotoItem: PhotosPickerItem?
    @State private var groupPhotoUploading = false
    private let pullCardDragThreshold: CGFloat = 160

    init(groupId: UUID) {
        self.groupId = groupId
        _viewModel = StateObject(wrappedValue: GroupHomeViewModel(groupId: groupId))
    }

    var body: some View {
        ZStack {
            Color.cardBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Group Header Card
                    groupHeaderCard

                    // Active Night Banner
                    if let activeNight = viewModel.activeNight {
                        activeNightBanner(activeNight)
                    }

                    // Petition Section
                    if viewModel.canPetition {
                        petitionSection
                    }

                    // Open Votes
                    if !viewModel.openVoteCases.isEmpty {
                        openVotesSection
                    }

                    // Members Section
                    membersSection

                    // Invite to Group & Invite by Link (admin only)
                    if viewModel.isAdmin {
                        addMembersSection
                        inviteByLinkSection
                    }

                    // Night History
                    if !viewModel.nights.isEmpty {
                        nightHistorySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, viewModel.canPullCard ? 140 : 32)
            }

            // Half-card at bottom: drag up to pull (only when can pull)
            if viewModel.canPullCard {
                pullCardHalfPeek
            }
        }
        .alert("Pull Blackout Card?", isPresented: $viewModel.showPullConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Pull Card") {
                viewModel.pullCard()
            }
        } message: {
            Text("This will notify everyone in the group. You're committing to a night out. Are you sure?")
        }
        .navigationTitle(viewModel.group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if viewModel.isAdmin {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdminSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdminSettings) {
            AdminSettingsView(groupId: groupId)
        }
        .sheet(isPresented: $showPetition) {
            PetitionRestoreView(groupId: groupId)
        }
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(groupId: groupId, groupName: viewModel.group?.name ?? "Group")
        }
        .alert("Link Copied", isPresented: $showInviteLinkCopied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Invite link copied to clipboard. Share it with friends so they can join the group.")
        }
        .navigationDestination(item: $navigateToNight) { night in
            NightView(nightId: night.id)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.refreshAndLoad()
        }
    }

    // MARK: - Group Header Card

    private var groupHeaderCard: some View {
        VStack(spacing: 16) {
            // Group photo (with optional change-photo for admins)
            ZStack(alignment: .bottomTrailing) {
                if let urlString = viewModel.group?.groupPhotoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 140)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.surfaceDark)
                                .frame(height: 140)
                                .overlay { ProgressView().tint(.white) }
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surfaceDark)
                        .frame(height: 140)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.textSecondary)
                        }
                }
                if groupPhotoUploading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(height: 140)
                        .overlay { ProgressView().tint(.white) }
                }
                if viewModel.isAdmin {
                    PhotosPicker(selection: $groupPhotoItem, matching: .images) {
                        Image(systemName: "camera.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, Color.accentPurple)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .disabled(groupPhotoUploading)
                }
            }
            .onChange(of: groupPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    await MainActor.run { groupPhotoUploading = true }
                    _ = await DataStore.shared.uploadGroupPhoto(groupId: groupId, imageData: data)
                    await MainActor.run {
                        groupPhotoUploading = false
                        groupPhotoItem = nil
                        viewModel.refreshAndLoad()
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                        Text("Private Group")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }

                    if let group = viewModel.group {
                        Text("\(group.periodType.rawValue) Period")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                // Current user's cards
                if let membership = viewModel.currentMembership {
                    VStack(spacing: 4) {
                        Text("Your Cards")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                        CardBadge(count: membership.cardsRemaining, large: true)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Active Night Banner

    private func activeNightBanner(_ night: Night) -> some View {
        Button {
            navigateToNight = night
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentPurple.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.accentPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Night")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(viewModel.pullerName(for: night)) pulled at \(night.pulledAt.timeFormatted)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.accentPurple)
            }
        }
        .glowingCardStyle(color: .accentPurple)
    }

    // MARK: - Pull Card (full-height from bottom; logo + "Pull to black out" at rest; pulls up to members area)

    private let pullCardPeekHeight: CGFloat = 120

    private var pullCardHalfPeek: some View {
        GeometryReader { geometry in
            let maxPullHeight = geometry.size.height * 0.55
            let cardHeight = pullCardPeekHeight + min(pullCardDragOffset, maxPullHeight)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentPurple.opacity(0.98), Color.accentPurple.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: cardHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)

                    VStack(spacing: 10) {
                        Image(systemName: "suit.spade.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.black)
                        Text("Pull to black out")
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.bottom, 44)
                }
                .frame(height: cardHeight)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let up = -value.translation.height
                            pullCardDragOffset = min(max(up, 0), maxPullHeight)
                        }
                        .onEnded { value in
                            let up = -value.translation.height
                            if up >= pullCardDragThreshold {
                                viewModel.showPullConfirmation = true
                            }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                pullCardDragOffset = 0
                            }
                        }
                )
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Petition Section

    private var petitionSection: some View {
        Button {
            showPetition = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundColor(.warningAmber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lost Your Card?")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Petition to restore it")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
        }
        .glowingCardStyle(color: .warningAmber)
    }

    // MARK: - Open Votes Section

    private var openVotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active Votes", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(viewModel.openVoteCases) { voteCase in
                NavigationLink(value: voteCase) {
                    HStack(spacing: 12) {
                        Image(systemName: voteCase.caseType == .failure ? "exclamationmark.triangle.fill" : "arrow.counterclockwise")
                            .foregroundColor(voteCase.caseType == .failure ? .dangerRed : .warningAmber)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(voteCase.caseType == .failure ? "Failure Vote" : "Petition")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("Target: \(DataStore.shared.userName(for: voteCase.targetUserId))")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        CountdownTimerView(deadline: voteCase.closesAt, compact: true)
                    }
                    .padding(12)
                    .background(Color.surfaceMedium)
                    .cornerRadius(12)
                }
            }
        }
        .cardStyle()
        .navigationDestination(for: VoteCase.self) { voteCase in
            VoteView(voteCaseId: voteCase.id)
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Members", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.members.count)")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }

            ForEach(viewModel.members) { memberInfo in
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.surfaceMedium)
                            .frame(width: 40, height: 40)
                        Text(String(memberInfo.user.name.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.accentPurple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(memberInfo.user.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            if memberInfo.membership.role == .admin {
                                Text("ADMIN")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.accentPurple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentPurple.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        if memberInfo.user.id == DataStore.shared.currentUser?.id {
                            Text("You")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()

                    CardBadge(count: memberInfo.membership.cardsRemaining)
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle()
    }

    // MARK: - Invite to Group Section

    private var addMembersSection: some View {
        Button {
            showAddMember = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.title3)
                    .foregroundColor(.accentPurple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite to Group")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Search by name or username")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Invite by Link Section

    private var inviteByLinkSection: some View {
        Button {
            let urlString = "blackout://invite/\(groupId.uuidString)"
            UIPasteboard.general.string = urlString
            showInviteLinkCopied = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundColor(.accentPurple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite by Link")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Copy link to share with friends")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.textSecondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Night History

    private var nightHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("History", systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(viewModel.nights) { night in
                Button {
                    navigateToNight = night
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: night.status == .active ? "moon.stars.fill" : "moon.fill")
                            .foregroundColor(night.status == .active ? .accentPurple : .textSecondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.pullerName(for: night))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(night.pulledAt.mediumFormatted)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Text(night.status.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(night.status == .active ? .accentPurple : .textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                (night.status == .active ? Color.accentPurple : Color.surfaceMedium).opacity(0.2)
                            )
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .cardStyle()
    }
}
