import SwiftUI

struct GroupHomeView: View {
    let groupId: UUID
    @StateObject private var viewModel: GroupHomeViewModel
    @State private var showAdminSettings = false
    @State private var showPetition = false
    @State private var navigateToNight: Night?

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

                    // Pull Card Section
                    if viewModel.canPullCard {
                        pullCardSection
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

                    // Night History
                    if !viewModel.nights.isEmpty {
                        nightHistorySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
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
        .navigationDestination(item: $navigateToNight) { night in
            NightView(nightId: night.id)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Group Header Card

    private var groupHeaderCard: some View {
        VStack(spacing: 16) {
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

    // MARK: - Pull Card Section

    private var pullCardSection: some View {
        VStack(spacing: 12) {
            // Visual card
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentPurple, Color.accentPurple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                    .shadow(color: .accentPurple.opacity(0.4), radius: 16)

                VStack(spacing: 8) {
                    Image(systemName: "suit.spade.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("BLACKOUT CARD")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Tap to pull your card tonight")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .onTapGesture {
                viewModel.showPullConfirmation = true
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

    // MARK: - Night History

    private var nightHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Night History", systemImage: "clock.fill")
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
