import SwiftUI
import PhotosUI

struct MediaUploadSheet: View {
    @ObservedObject var viewModel: NightViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImage: UIImage?
    @State private var caption = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Photo Picker
                        if let image = selectedImage {
                            // Preview
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(16)
                                .overlay(
                                    Button {
                                        selectedImage = nil
                                        selectedImageData = nil
                                        selectedItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(.black.opacity(0.5)))
                                    }
                                    .padding(8),
                                    alignment: .topTrailing
                                )
                        } else {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 48))
                                        .foregroundColor(.accentPurple)

                                    Text("Select a Photo")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("Choose from your library")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(Color.surfaceDark)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.accentPurple.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                                )
                            }
                        }

                        // Caption
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption (optional)")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            TextField("", text: $caption, prompt: Text("What's happening?").foregroundColor(.textSecondary.opacity(0.5)), axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color.surfaceMedium)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }

                        // Upload Button
                        Button {
                            uploadMedia()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Post to Feed")
                                }
                            }
                        }
                        .buttonStyle(BlackoutButtonStyle())
                        .disabled(selectedImageData == nil || isLoading)
                        .opacity(selectedImageData == nil ? 0.5 : 1)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Upload Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        selectedImage = UIImage(data: data)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func uploadMedia() {
        guard let imageData = selectedImageData else { return }
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.uploadMedia(
                imageData: imageData,
                caption: caption.isEmpty ? nil : caption
            )
            isLoading = false
            dismiss()
        }
    }
}
