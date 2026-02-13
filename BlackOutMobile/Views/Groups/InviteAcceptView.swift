import SwiftUI

/// Shown when the app is opened via an invite link. "Accept Invitation to [Group Name]" with Yes/No.
struct InviteAcceptView: View {
    let groupId: UUID
    var onDismiss: () -> Void

    @ObservedObject private var store = DataStore.shared
    @State private var didJoin = false

    private var group: Group? { store.group(for: groupId) }
    private var groupName: String { group?.name ?? "this group" }
    private var isAlreadyMember: Bool { store.isMember(of: groupId) }
    private var isAuthenticated: Bool { store.isAuthenticated }

    var body: some View {
        ZStack {
            Color.cardBlack.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer().frame(height: 24)

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentPurple.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.accentPurple)
                }

                Text("Accept Invitation")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                if !isAuthenticated {
                    Text("Sign in to accept your invitation to \(groupName).")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("You're invited to join \(groupName).")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if isAlreadyMember || didJoin {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.successGreen)
                        Text("You’re already in this group")
                            .font(.subheadline)
                            .foregroundColor(.successGreen)
                    }
                    .padding(.top, 8)
                }

                if group == nil {
                    Text("This invite link is invalid or the group no longer exists.")
                        .font(.caption)
                        .foregroundColor(.dangerRed)
                        .multilineTextAlignment(.center)
                }

                if !isAuthenticated {
                    Text("Close this screen, sign in, then open the invite link again to join.")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else if !isAlreadyMember && !didJoin && group != nil {
                    HStack(spacing: 16) {
                        Button {
                            decline()
                        } label: {
                            Text("No")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        Button {
                            accept()
                        } label: {
                            Text("Yes")
                        }
                        .buttonStyle(BlackoutButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }

                Button("Close") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .padding(.top, 24)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func accept() {
        Task {
            let ok = await store.joinGroup(groupId: groupId)
            if ok {
                didJoin = true
            }
        }
    }

    private func decline() {
        onDismiss()
    }
}
