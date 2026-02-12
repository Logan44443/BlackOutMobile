import Foundation
import SwiftUI
import Combine

@MainActor
class VoteViewModel: ObservableObject {
    let voteCaseId: UUID

    @Published var voteCase: VoteCase?
    @Published var allVotes: [Vote] = []
    @Published var hasVoted = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var isExpired = false
    @Published var yesCount = 0
    @Published var noCount = 0
    @Published var targetName = ""
    @Published var initiatorName = ""
    @Published var totalMembers = 0

    private let store = DataStore.shared
    private var timerCancellable: AnyCancellable?
    private var storeCancellable: AnyCancellable?

    init(voteCaseId: UUID) {
        self.voteCaseId = voteCaseId
        observeStore()
        loadData()
        startCountdown()
    }

    private func observeStore() {
        storeCancellable = store.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadData()
            }
    }

    func loadData() {
        voteCase = store.voteCase(for: voteCaseId)
        guard let voteCase else { return }

        allVotes = store.votesForCase(voteCaseId)
        hasVoted = store.hasCurrentUserVoted(on: voteCaseId)
        targetName = store.userName(for: voteCase.targetUserId)
        initiatorName = store.userName(for: voteCase.initiatedByUserId)

        let members = store.membersForGroup(voteCase.groupId)
        totalMembers = members.count

        yesCount = allVotes.filter { $0.value == .yes }.count
        noCount = allVotes.filter { $0.value == .no }.count

        let now = Date()
        timeRemaining = max(0, voteCase.closesAt.timeIntervalSince(now))
        isExpired = now >= voteCase.closesAt || voteCase.status == .resolved

        // Auto-resolve if time has passed
        if now >= voteCase.closesAt && voteCase.status == .open {
            store.resolveExpiredVoteCases()
        }
    }

    func castVote(value: VoteValue) {
        store.castVote(voteCaseId: voteCaseId, value: value)
        loadData()
    }

    private func startCountdown() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let vc = self.voteCase else { return }
                let remaining = vc.closesAt.timeIntervalSince(Date())
                self.timeRemaining = max(0, remaining)
                if remaining <= 0 && !self.isExpired {
                    self.isExpired = true
                    self.store.resolveExpiredVoteCases()
                    self.loadData()
                }
            }
    }

    deinit {
        timerCancellable?.cancel()
        storeCancellable?.cancel()
    }
}
