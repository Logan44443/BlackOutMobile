import SwiftUI

struct CreateGroupView: View {
    @ObservedObject var viewModel: GroupsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentPurple)

                    Text("Create a Group")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("Start a new Blackout Card group\nand invite your friends")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Name")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        TextField("", text: $viewModel.newGroupName, prompt: Text("e.g. Weekend Crew").foregroundColor(.textSecondary.opacity(0.5)))
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.surfaceMedium)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .focused($isNameFocused)
                    }
                    .padding(.horizontal, 4)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.dangerRed)
                    }

                    Button {
                        viewModel.createGroup()
                    } label: {
                        Text("Create Group")
                    }
                    .buttonStyle(BlackoutButtonStyle())

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.newGroupName = ""
                        viewModel.errorMessage = nil
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
