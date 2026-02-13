import Foundation
import SwiftUI

@MainActor
class GroupsViewModel: ObservableObject {
    @Published var groups: [GroupInfo] = []
    @Published var isLoading = false
    @Published var showCreateGroup = false
    @Published var newGroupName = ""
    @Published var errorMessage: String?

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
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let result = await self.store.createGroup(name: name)
            self.isLoading = false
            if result != nil {
                self.newGroupName = ""
                self.showCreateGroup = false
                self.loadGroups()
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
