import SwiftUI

struct StartVoteSheet: View {
    @ObservedObject var viewModel: NightViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.dangerRed)

                        Text("Start a Vote")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text("Select a member who didn't show up\nor engage tonight. The group will vote.")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Member List
                    VStack(spacing: 8) {
                        Text("Choose a Member")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(viewModel.voteEligibleMembers) { memberInfo in
                            Button {
                                viewModel.startVote(targetUserId: memberInfo.user.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.surfaceMedium)
                                            .frame(width: 40, height: 40)
                                        Text(String(memberInfo.user.name.prefix(1)).uppercased())
                                            .font(.headline)
                                            .foregroundColor(.accentPurple)
                                    }

                                    Text(memberInfo.user.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                }
                                .padding(12)
                                .background(Color.surfaceDark)
                                .cornerRadius(12)
                            }
                        }

                        if viewModel.voteEligibleMembers.isEmpty {
                            Text("No eligible members to vote against")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                                .padding(.vertical, 20)
                        }
                    }

                    // Warning
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.warningAmber)
                        Text("The vote will last 12 hours. If majority votes \"No Show\", the target loses their card for this period.")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(12)
                    .background(Color.warningAmber.opacity(0.1))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
