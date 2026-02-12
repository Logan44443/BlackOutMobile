import Foundation
import SwiftUI
import Combine

@MainActor
class NightViewModel: ObservableObject {
    let nightId: UUID

    @Published var night: Night?
    @Published var mediaItems: [MediaItem] = []
    @Published var isPuller = false
    @Published var voteCases: [VoteCase] = []
    @Published var pullerName = ""
    @Published var members: [MemberInfo] = []
    @Published var showMediaUpload = false
    @Published var showStartVote = false
    @Published var errorMessage: String?

    private let store = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init(nightId: UUID) {
        self.nightId = nightId
        observeStore()
        loadData()
    }

    private func observeStore() {
        store.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }

    func loadData() {
        night = store.night(for: nightId)
        guard let night else { return }

        mediaItems = store.mediaForNight(nightId)
        pullerName = store.userName(for: night.pulledByUserId)
        isPuller = night.pulledByUserId == store.currentUser?.id
        voteCases = store.voteCasesForNight(nightId)
        members = store.membersForGroup(night.groupId)

        store.resolveExpiredVoteCases()
    }

    func uploadMedia(imageData: Data, caption: String?) {
        guard let night else { return }
        store.addMedia(
            nightId: nightId,
            groupId: night.groupId,
            mediaType: .image,
            imageData: imageData,
            caption: caption
        )
        loadData()
    }

    func startVote(targetUserId: UUID) {
        guard let night else { return }
        let result = store.startFailureVote(
            groupId: night.groupId,
            nightId: nightId,
            targetUserId: targetUserId
        )
        if result == nil {
            errorMessage = "Unable to start vote. Only the card puller can initiate votes."
        }
        showStartVote = false
        loadData()
    }

    func uploaderName(for media: MediaItem) -> String {
        store.userName(for: media.uploaderUserId)
    }

    /// Members eligible for a failure vote (everyone except the puller)
    var voteEligibleMembers: [MemberInfo] {
        guard let night else { return [] }
        return members.filter { $0.user.id != night.pulledByUserId }
    }
}
