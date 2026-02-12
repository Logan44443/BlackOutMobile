import SwiftUI

struct AddMemberSheet: View {
    let groupId: UUID
    let groupName: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addedUserIds: Set<UUID> = []
    @State private var errorMessage: String?
    @FocusState private var isSearchFocused: Bool

    private let store = DataStore.shared

    private var availableUsers: [User] {
        let pool = store.usersNotInGroup(groupId)
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return pool
        }
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return pool.filter {
            $0.name.lowercased().contains(query) || $0.email.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.textSecondary)
                        TextField("Search by name or email", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .focused($isSearchFocused)
                            .autocapitalization(.none)
                    }
                    .padding(12)
                    .background(Color.surfaceDark)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.dangerRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    if availableUsers.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(availableUsers) { user in
                                    addMemberRow(user: user)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("Add to Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.accentPurple)
                }
            }
        }
    }

    private func addMemberRow(user: User) -> some View {
        let alreadyAdded = addedUserIds.contains(user.id)

        return Button {
            guard !alreadyAdded else { return }
            let success = store.addMemberToGroup(groupId: groupId, userId: user.id)
            if success {
                addedUserIds.insert(user.id)
                errorMessage = nil
            } else {
                errorMessage = "Could not add \(user.name)."
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.surfaceMedium)
                        .frame(width: 44, height: 44)
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.accentPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                if alreadyAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.successGreen)
                } else {
                    Text("Add")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentPurple)
                }
            }
            .padding(12)
            .background(Color.surfaceDark)
            .cornerRadius(12)
        }
        .disabled(alreadyAdded)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.surfaceMedium)
            Text("No one to add")
                .font(.headline)
                .foregroundColor(.white)
            Text(searchText.isEmpty
                 ? "Everyone in the app is already in this group."
                 : "No one matches \"\(searchText)\"."
            )
            .font(.subheadline)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
