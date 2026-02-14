import Foundation
import SwiftUI
import Combine

@MainActor
class GroupHomeViewModel: ObservableObject {
    let groupId: UUID

    @Published var group: Group?
    @Published var members: [MemberInfo] = []
    @Published var nights: [Night] = []
    @Published var activeNight: Night?
    @Published var currentMembership: Membership?
    @Published var openVoteCases: [VoteCase] = []
    @Published var canPullCard = false
    @Published var canPetition = false
    @Published var isAdmin = false
    @Published var showPullConfirmation = false
    @Published var errorMessage: String?

    private let store = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init(groupId: UUID) {
        self.groupId = groupId
        observeStore()
        loadData()
        Task {
            await store.refreshGroupData(groupId: groupId)
            await store.refreshNotificationsForCurrentUser()
            loadData()
        }
    }

    /// Call when the group screen appears so canPullCard uses fresh server data for this group only.
    func refreshAndLoad() {
        Task {
            await store.refreshGroupData(groupId: groupId)
            await store.refreshNotificationsForCurrentUser()
            loadData()
        }
    }

    private func observeStore() {
        // Re-load when any store data changes
        store.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }

    func loadData() {
        group = store.group(for: groupId)
        members = store.membersForGroup(groupId)
        nights = store.nightsForGroup(groupId)
        activeNight = store.activeNight(for: groupId)
        currentMembership = store.membershipForCurrentUser(in: groupId)
        openVoteCases = store.openVoteCasesForGroup(groupId)
        isAdmin = store.isAdmin(of: groupId)

        canPullCard = (currentMembership?.cardsRemaining ?? 0) > 0 && activeNight == nil
        canPetition = store.canPetition(groupId: groupId)

        // Also check/resolve expired votes (server-side)
        store.resolveExpiredVoteCases()
    }

    func pullCard() {
        Task {
            let result = await store.pullCard(in: groupId)
            switch result {
            case .success:
                break
            case .noCardsRemaining:
                errorMessage = "You have no cards remaining in this group. Wait for a period reset or a successful petition."
            case .activeNightExists:
                errorMessage = "There's already an active night in this group. Close it first or wait for the period to reset."
            case .notFoundOrDenied:
                errorMessage = "Could not find your membership in this group. Try leaving and rejoining, or refresh the screen."
            case .error(let message):
                errorMessage = "Unable to pull card: \(message)"
            }
            loadData()
        }
    }

    func closeNight() {
        guard let night = activeNight else { return }
        Task {
            await store.closeNight(night.id)
            loadData()
        }
    }

    func pullerName(for night: Night) -> String {
        store.userName(for: night.pulledByUserId)
    }
}
