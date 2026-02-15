import SwiftUI
import PhotosUI

struct AdminSettingsView: View {
    let groupId: UUID
    @StateObject private var viewModel: AdminSettingsViewModel
    @ObservedObject private var store = DataStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var profilePhotoItem: PhotosPickerItem?
    @State private var coverPhotoItem: PhotosPickerItem?
    @State private var profileUploading = false
    @State private var coverUploading = false

    init(groupId: UUID) {
        self.groupId = groupId
        _viewModel = StateObject(wrappedValue: AdminSettingsViewModel(groupId: groupId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Group Profile Photo (circle)
                        settingSection(title: "Group Profile Photo", icon: "person.circle.fill") {
                            HStack(spacing: 16) {
                                adminGroupProfileCircle
                                Text("Shows on My Groups list")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                Spacer()
                                if profileUploading {
                                    ProgressView().tint(.white)
                                } else {
                                    PhotosPicker(selection: $profilePhotoItem, matching: .images) {
                                        Label("Change", systemImage: "camera.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.accentPurple)
                                    }
                                }
                            }
                        }
                        .onChange(of: profilePhotoItem) { _, newItem in
                            guard let newItem else { return }
                            Task {
                                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                                await MainActor.run { profileUploading = true }
                                _ = await store.uploadGroupPhoto(groupId: groupId, imageData: data)
                                await MainActor.run {
                                    profileUploading = false
                                    profilePhotoItem = nil
                                }
                            }
                        }

                        // Cover Photo (rectangle)
                        settingSection(title: "Cover Photo", icon: "rectangle.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                adminCoverPreview
                                if coverUploading {
                                    HStack { ProgressView().tint(.white); Spacer() }
                                } else {
                                    PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                                        Label("Change Cover Photo", systemImage: "camera.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.accentPurple)
                                    }
                                }
                            }
                        }
                        .onChange(of: coverPhotoItem) { _, newItem in
                            guard let newItem else { return }
                            Task {
                                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                                await MainActor.run { coverUploading = true }
                                _ = await store.uploadGroupCoverPhoto(groupId: groupId, imageData: data)
                                await MainActor.run {
                                    coverUploading = false
                                    coverPhotoItem = nil
                                }
                            }
                        }

                        // Cards Per Period
                        settingSection(title: "Cards Per Period", icon: "suit.spade.fill") {
                            Stepper(value: $viewModel.cardsPerPeriod, in: 1...10) {
                                HStack {
                                    Text("\(viewModel.cardsPerPeriod)")
                                        .font(.title2.bold())
                                        .foregroundColor(.accentPurple)
                                    Text(viewModel.cardsPerPeriod == 1 ? "card" : "cards")
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .tint(.accentPurple)
                        }

                        // Period Type
                        settingSection(title: "Period Type", icon: "calendar") {
                            Picker("Period Type", selection: $viewModel.periodType) {
                                ForEach(PeriodType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Period Dates
                        if viewModel.periodType == .custom {
                            settingSection(title: "Period Dates", icon: "calendar.badge.clock") {
                                VStack(spacing: 12) {
                                    DatePicker("Start", selection: $viewModel.periodStart, displayedComponents: .date)
                                        .foregroundColor(.white)
                                    DatePicker("End", selection: $viewModel.periodEnd, displayedComponents: .date)
                                        .foregroundColor(.white)
                                }
                                .tint(.accentPurple)
                            }
                        }

                        // Vote Duration (read-only)
                        settingSection(title: "Vote Duration", icon: "clock.fill") {
                            HStack {
                                Text("\(viewModel.voteDurationHours) hours")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Fixed")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.surfaceMedium)
                                    .cornerRadius(8)
                            }
                        }

                        // Vote Threshold (read-only)
                        settingSection(title: "Vote Threshold", icon: "chart.pie.fill") {
                            HStack {
                                Text("Majority")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Default")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.surfaceMedium)
                                    .cornerRadius(8)
                            }
                        }

                        // Save Button
                        Button {
                            viewModel.saveSettings()
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.saveSuccessful {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Saved!")
                                } else {
                                    Image(systemName: "checkmark")
                                    Text("Save Settings")
                                }
                            }
                        }
                        .buttonStyle(BlackoutButtonStyle(color: viewModel.saveSuccessful ? .successGreen : .accentPurple))

                        Divider()
                            .background(Color.surfaceMedium)

                        // Reset Period (Danger Zone)
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.dangerRed)
                                Text("Danger Zone")
                                    .font(.headline)
                                    .foregroundColor(.dangerRed)
                            }

                            Text("Resetting the period will restore all members' cards and close any active nights.")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)

                            Button {
                                viewModel.showResetConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset Period Now")
                                }
                            }
                            .buttonStyle(BlackoutButtonStyle(color: .dangerRed))
                        }
                        .padding()
                        .background(Color.dangerRed.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.dangerRed.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.accentPurple)
                }
            }
            .alert("Reset Period?", isPresented: $viewModel.showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.resetPeriod()
                }
            } message: {
                Text("This will restore all members' cards to \(viewModel.cardsPerPeriod) and close any active nights. This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private var adminGroupProfileCircle: some View {
        let group = store.group(for: groupId)
        if let urlString = group?.groupPhotoUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color.surfaceDark)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.accentPurple.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay(
                    Text(String((group?.name ?? "G").prefix(1)).uppercased())
                        .font(.title3.bold())
                        .foregroundColor(.accentPurple)
                )
        }
    }

    @ViewBuilder
    private var adminCoverPreview: some View {
        let group = store.group(for: groupId)
        if let urlString = group?.coverPhotoUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Color.surfaceDark)
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfaceDark)
                .frame(height: 80)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.textSecondary)
                )
        }
    }

    // MARK: - Setting Section Builder

    @ViewBuilder
    private func settingSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(.textSecondary)

            content()
        }
        .cardStyle()
    }
}
