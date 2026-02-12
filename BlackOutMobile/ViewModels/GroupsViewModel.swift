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

        let result = store.createGroup(name: newGroupName.trimmingCharacters(in: .whitespaces))
        if result != nil {
            newGroupName = ""
            showCreateGroup = false
            loadGroups()
        } else {
            errorMessage = "Failed to create group"
        }
    }

    func deleteGroup(_ groupInfo: GroupInfo) {
        store.leaveGroup(groupId: groupInfo.group.id)
        loadGroups()
    }

    func unreadCount() -> Int {
        store.unreadCount()
    }
}
