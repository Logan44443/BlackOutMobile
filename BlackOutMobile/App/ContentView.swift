import SwiftUI

/// Used to present the invite-accept sheet when the app is opened via blackout://invite/<groupId>
private struct PendingInvite: Identifiable {
    let groupId: UUID
    var id: UUID { groupId }
}

struct ContentView: View {
    @ObservedObject private var store = DataStore.shared
    @StateObject private var authViewModel = AuthViewModel()
    @State private var pendingInvite: PendingInvite?

    var body: some View {
        SwiftUI.Group {
            if store.isAuthenticated {
                GroupsListView()
                    .withNotificationBanner()
                    .transition(.opacity)
            } else {
                LoginView(viewModel: authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(Animation.easeInOut(duration: 0.3), value: store.isAuthenticated)
        .onOpenURL { url in
            guard url.scheme == "blackout", url.host == "invite" else { return }
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let groupId = UUID(uuidString: path) else { return }
            pendingInvite = PendingInvite(groupId: groupId)
        }
        .sheet(item: $pendingInvite) { invite in
            InviteAcceptView(groupId: invite.groupId) {
                pendingInvite = nil
            }
        }
    }
}
