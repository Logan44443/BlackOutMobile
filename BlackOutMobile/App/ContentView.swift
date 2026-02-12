import SwiftUI

struct ContentView: View {
    @ObservedObject private var store = DataStore.shared
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if store.isAuthenticated {
                GroupsListView()
                    .withNotificationBanner()
                    .transition(.opacity)
            } else {
                LoginView(viewModel: authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.isAuthenticated)
    }
}
