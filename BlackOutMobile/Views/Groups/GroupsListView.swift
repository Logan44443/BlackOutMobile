import SwiftUI

struct GroupsListView: View {
    @StateObject private var viewModel = GroupsViewModel()
    @ObservedObject private var store = DataStore.shared
    @State private var showNotifications = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            groupsContent
                .navigationTitle("My Groups")
                .navigationBarTitleDisplayMode(.large)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showProfile) { ProfileView() }
                .sheet(isPresented: $viewModel.showCreateGroup) { CreateGroupView(viewModel: viewModel) }
                .sheet(isPresented: $showNotifications) { NotificationsListView() }
                .alert("Group created", isPresented: Binding(
                    get: { viewModel.groupCreatedPhotoFailedMessage != nil },
                    set: { if !$0 { viewModel.groupCreatedPhotoFailedMessage = nil } }
                )) {
                    Button("OK") { viewModel.groupCreatedPhotoFailedMessage = nil }
                } message: {
                    Text(viewModel.groupCreatedPhotoFailedMessage ?? "")
                }
                .onAppear {
                    viewModel.loadGroups()
                    Task {
                        await store.refreshGroups()
                        viewModel.loadGroups()
                    }
                }
                .onChange(of: viewModel.showCreateGroup) { _, isShowing in
                    if !isShowing {
                        Task {
                            await store.refreshGroups()
                            viewModel.loadGroups()
                        }
                    }
                }
                .onChange(of: store.groups.count) { viewModel.loadGroups() }
                .onChange(of: store.memberships) { _, _ in viewModel.loadGroups() }
        }
    }

    @ViewBuilder
    private var groupsContent: some View {
        ZStack {
            Color.cardBlack.ignoresSafeArea()
            if viewModel.groups.isEmpty {
                emptyStateView
            } else {
                groupsList
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill").foregroundColor(.white)
                    if viewModel.unreadCount() > 0 {
                        Text("\(viewModel.unreadCount())")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.dangerRed)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { viewModel.showCreateGroup = true } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentPurple)
                    .font(.title3)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showProfile = true } label: {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                Divider()
                Button(role: .destructive) { Task { await store.logout() } } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                profileMenuLabel
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
        }
    }

    @ViewBuilder
    private var profileMenuLabel: some View {
        ZStack {
            Image(systemName: "person.circle")
                .foregroundColor(.white)
                .font(.system(size: 32))
            if let urlString = store.currentUser?.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            }
        }
    }

    // MARK: - Groups List

    private var groupsList: some View {
        let sortedGroups = viewModel.groups
            .sorted { $0.group.name.localizedCaseInsensitiveCompare($1.group.name) == .orderedAscending }
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sortedGroups) { groupInfo in
                    NavigationLink(value: groupInfo) {
                        GroupRowView(groupInfo: groupInfo)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            await store.refreshGroups()
            await MainActor.run { viewModel.loadGroups() }
        }
        .navigationDestination(for: GroupInfo.self) { groupInfo in
            GroupHomeView(groupId: groupInfo.group.id)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 56))
                .foregroundColor(.surfaceMedium)

            Text("No Groups Yet")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Create a group to start playing\nBlackout Card with your friends")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.showCreateGroup = true
            } label: {
                Text("Create Group")
            }
            .buttonStyle(BlackoutButtonStyle())
            .padding(.horizontal, 60)
            .padding(.top, 8)
        }
    }
}

// MARK: - Group Row

struct GroupRowView: View {
    let groupInfo: GroupInfo

    var body: some View {
        HStack(spacing: 16) {
            // Group Photo or Fallback Icon
            groupIcon

            // Group Info
            VStack(alignment: .leading, spacing: 4) {
                Text(groupInfo.group.name)
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Label(groupInfo.membership.role.rawValue, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            // Cards Badge
            CardBadge(count: groupInfo.membership.cardsRemaining)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(16)
        .background(Color.surfaceDark)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var groupIcon: some View {
        if let urlString = groupInfo.group.groupPhotoUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                case .failure:
                    groupIconPlaceholder
                case .empty:
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.surfaceDark)
                        .frame(width: 52, height: 52)
                        .overlay { ProgressView().tint(.white) }
                @unknown default:
                    groupIconPlaceholder
                }
            }
            .id(urlString)
        } else {
            groupIconPlaceholder
        }
    }

    private var groupIconPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentPurple.opacity(0.2))
                .frame(width: 52, height: 52)

            Text(String(groupInfo.group.name.prefix(1)).uppercased())
                .font(.title2.bold())
                .foregroundColor(.accentPurple)
        }
    }
}
