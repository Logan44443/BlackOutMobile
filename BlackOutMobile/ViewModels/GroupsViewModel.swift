import Foundation
import SwiftUI

@MainActor
class GroupsViewModel: ObservableObject {
    @Published var groups: [GroupInfo] = []
    @Published var isLoading = false
    @Published var showCreateGroup = false
    @Published var newGroupName = ""
    @Published var newGroupPhotoData: Data?
    @Published var errorMessage: String?
    /// Shown when group was created but photo upload failed (e.g. Storage 403).
    @Published var groupCreatedPhotoFailedMessage: String?

    // Join group via invite code (simulated)
    @Published var showJoinGroup = false
    @Published var joinGroupName = ""

    private let store = DataStore.shared

    func loadGroups() {
        groups = store.groupsForCurrentUser()
    }

    func createGroup() {
        guard !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a group name"
            return
        }

        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        let photoData = newGroupPhotoData
        isLoading = true
        groupCreatedPhotoFailedMessage = nil
        Task { [weak self] in
            guard let self else { return }
            let (group, photoUploadFailed) = await self.store.createGroup(name: name, photoData: photoData)
            self.isLoading = false
            if group != nil {
                self.newGroupName = ""
                self.newGroupPhotoData = nil
                // Store was already refreshed inside createGroup (with new group + photo); push to list then close sheet
                self.loadGroups()
                self.showCreateGroup = false
                if photoUploadFailed {
                    self.groupCreatedPhotoFailedMessage = "Group created. Photo couldn’t be uploaded—check Storage (avatars/media) RLS in Supabase."
                }
            } else {
                self.errorMessage = "Failed to create group"
            }
        }
    }

    func deleteGroup(_ groupInfo: GroupInfo) {
        Task { [weak self] in
            guard let self else { return }
            await self.store.leaveGroup(groupId: groupInfo.group.id)
            self.loadGroups()
        }
    }

    func unreadCount() -> Int {
        store.unreadCount()
    }
}
