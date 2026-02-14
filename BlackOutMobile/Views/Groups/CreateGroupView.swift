import SwiftUI
import PhotosUI

struct CreateGroupView: View {
    @ObservedObject var viewModel: GroupsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    /// Local preview for the picker label (avoids MainActor-isolated viewModel access in nonisolated context).
    @State private var groupPhotoPreview: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        // Group photo picker
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                if let uiImage = groupPhotoPreview {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                } else {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.surfaceDark)
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.3.fill")
                                                .font(.system(size: 36))
                                                .foregroundColor(.accentPurple)
                                        )
                                }
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.accentPurple.opacity(0.5), lineWidth: 2)
                                    .frame(width: 100, height: 100)
                                Image(systemName: "camera.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                                    .offset(x: 38, y: 38)
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                let data = try? await newItem?.loadTransferable(type: Data.self)
                                await MainActor.run {
                                    viewModel.newGroupPhotoData = data
                                    groupPhotoPreview = data.flatMap { UIImage(data: $0) }
                                }
                            }
                        }

                        Text("Tap to add group photo")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.newGroupName = ""
                        viewModel.newGroupPhotoData = nil
                        viewModel.errorMessage = nil
                        groupPhotoPreview = nil
                        selectedPhotoItem = nil
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
