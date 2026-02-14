import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = DataStore.shared
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarImageData: Data?
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var user: User? { store.currentUser }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile photo
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                if let data = avatarImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let urlString = user?.avatarUrl, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        default:
                                            avatarPlaceholder
                                        }
                                    }
                                } else {
                                    avatarPlaceholder
                                }
                                Circle()
                                    .stroke(Color.accentPurple.opacity(0.5), lineWidth: 2)
                                    .frame(width: 100, height: 100)
                                Image(systemName: "camera.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                                    .offset(x: 34, y: 34)
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                guard let newItem else {
                                    avatarImageData = nil
                                    return
                                }
                                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                                await MainActor.run { avatarImageData = data }
                                // Auto-save so "pick photo then leave" still persists the new picture
                                let currentName = store.currentUser?.name ?? ""
                                let currentUsername = store.currentUser?.username ?? ""
                                let (success, error) = await store.updateProfile(
                                    avatarImageData: data,
                                    name: currentName,
                                    username: currentUsername,
                                    email: nil,
                                    newPassword: nil,
                                    currentPassword: nil
                                )
                                await MainActor.run {
                                    if success {
                                        errorMessage = nil
                                        successMessage = "Profile picture updated."
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { successMessage = nil }
                                    } else {
                                        errorMessage = error ?? "Could not save photo."
                                    }
                                }
                            }
                        }

                        Text("Tap to change photo")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        // Name, Username, Email (no password required for name/username)
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Profile", systemImage: "person.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.textSecondary)

                            profileField("Name", text: $name)
                            profileField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocapitalization(.none)
                            profileField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                        .cardStyle()

                        // Current password + change password (required to change email or password)
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Change email or password", systemImage: "lock.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.textSecondary)

                            Text("Enter your current password to confirm your identity.")
                                .font(.caption)
                                .foregroundColor(.textSecondary)

                            secureField("Current password", text: $currentPassword)
                            secureField("New password (optional)", text: $newPassword)
                            secureField("Confirm new password", text: $confirmPassword)
                        }
                        .cardStyle()

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.dangerRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let success = successMessage {
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.successGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            saveProfile()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .buttonStyle(BlackoutButtonStyle())
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.accentPurple)
                }
            }
            .onAppear {
                Task {
                    await store.refreshCurrentUserProfileIfNeeded()
                    await MainActor.run {
                        name = store.currentUser?.name ?? ""
                        username = store.currentUser?.username ?? ""
                        email = store.currentUser?.email ?? ""
                    }
                }
            }
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.surfaceDark)
                .frame(width: 100, height: 100)
            Text(String((user?.name ?? "?").prefix(1)).uppercased())
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.accentPurple)
        }
    }

    private func profileField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.surfaceMedium)
                .cornerRadius(12)
                .foregroundColor(.white)
        }
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
            SecureField("", text: text)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.surfaceMedium)
                .cornerRadius(12)
                .foregroundColor(.white)
        }
    }

    private func saveProfile() {
        errorMessage = nil
        successMessage = nil

        let emailChanged = email != (user?.email ?? "")
        let passwordChanged = !newPassword.isEmpty || !confirmPassword.isEmpty

        if passwordChanged, newPassword != confirmPassword {
            errorMessage = "New password and confirmation don't match."
            return
        }
        if passwordChanged, newPassword.count < 6 {
            errorMessage = "New password must be at least 6 characters."
            return
        }
        if (emailChanged || passwordChanged), currentPassword.isEmpty {
            errorMessage = "Enter your current password to change email or password."
            return
        }

        // Only pass avatar data if the user actually picked a NEW photo
        // (selectedPhotoItem changed). Don't re-upload existing data.
        let newAvatarData: Data? = selectedPhotoItem != nil ? avatarImageData : nil

        isLoading = true
        Task {
            let result = await store.updateProfile(
                avatarImageData: newAvatarData,
                name: name,
                username: username,
                email: emailChanged ? email : nil,
                newPassword: passwordChanged ? newPassword : nil,
                currentPassword: (emailChanged || passwordChanged) ? currentPassword : nil
            )

            isLoading = false

            if result.success {
                successMessage = "Profile updated."
                selectedPhotoItem = nil   // Reset so next save won't re-upload
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { successMessage = nil }
            } else {
                errorMessage = result.error
            }
        }
    }
}
