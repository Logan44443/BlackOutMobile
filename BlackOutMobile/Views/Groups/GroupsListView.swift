import SwiftUI

struct GroupsListView: View {
    @StateObject private var viewModel = GroupsViewModel()
    @ObservedObject private var store = DataStore.shared
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                if viewModel.groups.isEmpty {
                    emptyStateView
                } else {
                    groupsList
                }
            }
            .navigationTitle("My Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showNotifications = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.white)
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
                    Button {
                        viewModel.showCreateGroup = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentPurple)
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            store.logout()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateGroup) {
                CreateGroupView(viewModel: viewModel)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsListView()
            }
            .onAppear {
                viewModel.loadGroups()
            }
            .onChange(of: store.groups.count) {
                viewModel.loadGroups()
            }
            .onChange(of: store.memberships) { _, _ in
                viewModel.loadGroups()
            }
        }
    }

    // MARK: - Groups List

    private var groupsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groups) { groupInfo in
                    NavigationLink(value: groupInfo) {
                        GroupRowView(groupInfo: groupInfo)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
            // Group Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentPurple.opacity(0.2))
                    .frame(width: 52, height: 52)

                Text(String(groupInfo.group.name.prefix(1)).uppercased())
                    .font(.title2.bold())
                    .foregroundColor(.accentPurple)
            }

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
}
