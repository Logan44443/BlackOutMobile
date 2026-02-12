import SwiftUI

struct NightView: View {
    let nightId: UUID
    @StateObject private var viewModel: NightViewModel
    @State private var navigateToVoteCase: VoteCase?

    init(nightId: UUID) {
        self.nightId = nightId
        _viewModel = StateObject(wrappedValue: NightViewModel(nightId: nightId))
    }

    var body: some View {
        ZStack {
            Color.cardBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Night Header
                    nightHeader

                    // Action Buttons (puller only)
                    if viewModel.isPuller, viewModel.night?.status == .active {
                        pullerActions
                    }

                    // Active Votes
                    if !viewModel.voteCases.isEmpty {
                        voteCasesSection
                    }

                    // Media Feed
                    mediaFeedSection

                    // Upload button for all members during active night
                    if viewModel.night?.status == .active {
                        Button {
                            viewModel.showMediaUpload = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                Text("Add to Feed")
                            }
                        }
                        .buttonStyle(BlackoutButtonStyle())
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Night")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $viewModel.showMediaUpload) {
            MediaUploadSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showStartVote) {
            StartVoteSheet(viewModel: viewModel)
        }
        .navigationDestination(item: $navigateToVoteCase) { voteCase in
            VoteView(voteCaseId: voteCase.id)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Night Header

    private var nightHeader: some View {
        VStack(spacing: 16) {
            // Large card visual
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                viewModel.night?.status == .active ? Color.accentPurple : Color.surfaceMedium,
                                viewModel.night?.status == .active ? Color.accentPurple.opacity(0.5) : Color.surfaceDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 160)
                    .shadow(
                        color: viewModel.night?.status == .active ? .accentPurple.opacity(0.3) : .clear,
                        radius: 16
                    )

                VStack(spacing: 12) {
                    Image(systemName: "suit.spade.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)

                    Text("\(viewModel.pullerName) pulled their card")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let night = viewModel.night {
                        Text(night.pulledAt.mediumFormatted)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 16)

            // Status badge
            if let night = viewModel.night {
                HStack(spacing: 8) {
                    Circle()
                        .fill(night.status == .active ? Color.successGreen : Color.textSecondary)
                        .frame(width: 8, height: 8)
                    Text(night.status == .active ? "Night is Active" : "Night Closed")
                        .font(.subheadline.bold())
                        .foregroundColor(night.status == .active ? .successGreen : .textSecondary)
                }
            }
        }
    }

    // MARK: - Puller Actions

    private var pullerActions: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.showStartVote = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Start Vote Against Someone")
                }
            }
            .buttonStyle(BlackoutButtonStyle(color: .dangerRed))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Vote Cases Section

    private var voteCasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Votes", systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(viewModel.voteCases) { voteCase in
                Button {
                    navigateToVoteCase = voteCase
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: voteCase.caseType == .failure ? "exclamationmark.triangle.fill" : "arrow.counterclockwise")
                            .foregroundColor(voteCase.status == .open
                                ? (voteCase.caseType == .failure ? .dangerRed : .warningAmber)
                                : .textSecondary
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(voteCase.caseType.rawValue) - \(DataStore.shared.userName(for: voteCase.targetUserId))")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)

                            if voteCase.status == .resolved {
                                Text("Result: \(voteCase.result?.rawValue ?? "N/A")")
                                    .font(.caption)
                                    .foregroundColor(voteCase.result == .pass ? .dangerRed : .successGreen)
                            }
                        }

                        Spacer()

                        if voteCase.status == .open {
                            CountdownTimerView(deadline: voteCase.closesAt, compact: true)
                        } else {
                            Text("Resolved")
                                .font(.caption.bold())
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(Color.surfaceMedium)
                    .cornerRadius(12)
                }
            }
        }
        .cardStyle()
        .padding(.horizontal, 16)
    }

    // MARK: - Media Feed Section

    private var mediaFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Night Feed", systemImage: "photo.stack.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.mediaItems.count) posts")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            if viewModel.mediaItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundColor(.surfaceMedium)
                    Text("No media yet")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Text("Be the first to post!")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(viewModel.mediaItems) { item in
                    MediaPostView(item: item, uploaderName: viewModel.uploaderName(for: item))
                }
            }
        }
        .cardStyle()
        .padding(.horizontal, 16)
    }
}

// MARK: - Media Post View

struct MediaPostView: View {
    let item: MediaItem
    let uploaderName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Uploader info
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.surfaceMedium)
                        .frame(width: 32, height: 32)
                    Text(String(uploaderName.prefix(1)).uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.accentPurple)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(uploaderName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(item.createdAt.relativeFormatted)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }

            // Image
            if let imageData = item.localImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 300)
                    .clipped()
                    .cornerRadius(12)
            } else if item.mediaType == .video {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.surfaceMedium)
                        .frame(height: 200)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Caption
            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.surfaceMedium)
        }
        .padding(.vertical, 4)
    }
}
