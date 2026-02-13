import SwiftUI

struct AddMemberSheet: View {
    let groupId: UUID
    let groupName: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [User] = []
    @State private var isLoading = false
    @State private var addedUserIds: Set<UUID> = []
    @State private var errorMessage: String?
    @FocusState private var isSearchFocused: Bool
    @State private var searchTask: Task<Void, Never>?

    private let store = DataStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.textSecondary)
                        TextField("Search by name or username", text: $searchText)
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
                    .onChange(of: searchText) { _, newValue in
                        performSearch(newValue)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.dangerRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    if isLoading {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 40)
                            ProgressView()
                                .tint(.accentPurple)
                            Text("Searching…")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else if results.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(results) { user in
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
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    private func addMemberRow(user: User) -> some View {
        let alreadyAdded = addedUserIds.contains(user.id)

        return Button {
            guard !alreadyAdded else { return }
            Task {
                let success = await store.addMemberToGroup(groupId: groupId, userId: user.id)
                if success {
                    addedUserIds.insert(user.id)
                    errorMessage = nil
                } else {
                    errorMessage = "Could not add \(user.name)."
                }
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
                    Text("@\(user.username)")
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
            Text(searchText.trimmingCharacters(in: .whitespaces).isEmpty ? "Search for someone" : "No results")
                .font(.headline)
                .foregroundColor(.white)
            Text(searchText.isEmpty
                 ? "Type a name or username to add someone."
                 : "No one matches \"\(searchText)\"."
            )
            .font(.subheadline)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func performSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            return
        }

        searchTask = Task {
            // lightweight debounce
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            isLoading = true
            let found = await store.searchProfilesNotInGroup(groupId: groupId, query: trimmed)
            guard !Task.isCancelled else { return }
            results = found
            isLoading = false
        }
    }
}
