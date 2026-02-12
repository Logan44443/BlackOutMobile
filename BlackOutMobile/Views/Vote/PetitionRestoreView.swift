import SwiftUI

struct PetitionRestoreView: View {
    let groupId: UUID
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = DataStore.shared
    @State private var showConfirmation = false
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Visual
                    ZStack {
                        Circle()
                            .fill(Color.warningAmber.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.warningAmber)
                    }

                    Text("Petition to Restore Your Card")
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Text("You've lost your Blackout Card for this period.\nPetition the group to get it back.")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    // Info Box
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "clock.fill", text: "Voting lasts 12 hours")
                        InfoRow(icon: "person.2.fill", text: "Majority of group must approve")
                        InfoRow(icon: "1.circle.fill", text: "You can only petition once per period")
                    }
                    .padding()
                    .background(Color.surfaceDark)
                    .cornerRadius(16)

                    if submitted {
                        // Success state
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.successGreen)
                            Text("Petition Submitted!")
                                .font(.headline)
                                .foregroundColor(.successGreen)
                            Text("The group has been notified and voting has begun.")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        Button("Done") { dismiss() }
                            .buttonStyle(BlackoutButtonStyle())
                    } else {
                        Button {
                            showConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                Text("Submit Petition")
                            }
                        }
                        .buttonStyle(BlackoutButtonStyle(color: .warningAmber))
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
            }
            .alert("Submit Petition?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Submit") {
                    let result = store.startPetition(groupId: groupId)
                    if result != nil {
                        withAnimation {
                            submitted = true
                        }
                    }
                }
            } message: {
                Text("This will start a 12-hour group vote. You can only petition once per period.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Info Row Helper

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.warningAmber)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
    }
}
