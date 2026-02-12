import SwiftUI

struct VoteView: View {
    let voteCaseId: UUID
    @StateObject private var viewModel: VoteViewModel

    init(voteCaseId: UUID) {
        self.voteCaseId = voteCaseId
        _viewModel = StateObject(wrappedValue: VoteViewModel(voteCaseId: voteCaseId))
    }

    var body: some View {
        ZStack {
            Color.cardBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    voteHeader

                    // Countdown
                    countdownSection

                    // Vote Prompt & Buttons
                    if !viewModel.isExpired && !viewModel.hasVoted {
                        votePromptSection
                    }

                    // Status after voting
                    if viewModel.hasVoted && !viewModel.isExpired {
                        votedConfirmation
                    }

                    // Results (shown after expiry or after voting)
                    if viewModel.isExpired || viewModel.hasVoted {
                        resultsSection
                    }

                    // Final Result (only when resolved)
                    if let voteCase = viewModel.voteCase, voteCase.status == .resolved {
                        finalResultSection(voteCase)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(viewModel.voteCase?.caseType == .petition ? "Petition" : "Vote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Vote Header

    private var voteHeader: some View {
        VStack(spacing: 16) {
            let isPetition = viewModel.voteCase?.caseType == .petition

            ZStack {
                Circle()
                    .fill((isPetition ? Color.warningAmber : Color.dangerRed).opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: isPetition ? "arrow.counterclockwise.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isPetition ? .warningAmber : .dangerRed)
            }

            if isPetition {
                Text("Petition to Restore Card")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("\(viewModel.targetName) is petitioning to get their Blackout Card back")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Failure Vote")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Did \(viewModel.targetName) honor the card by showing up and engaging?")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 4) {
                Text("Initiated by")
                    .foregroundColor(.textSecondary)
                Text(viewModel.initiatorName)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
            .font(.caption)
        }
        .cardStyle()
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        VStack(spacing: 8) {
            if viewModel.isExpired {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.textSecondary)
                    Text("Voting Period Ended")
                        .font(.headline)
                        .foregroundColor(.textSecondary)
                }
            } else if let vc = viewModel.voteCase {
                CountdownTimerView(deadline: vc.closesAt, compact: false)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Vote Prompt

    private var votePromptSection: some View {
        VStack(spacing: 16) {
            let isPetition = viewModel.voteCase?.caseType == .petition

            Text(isPetition ? "Should \(viewModel.targetName) get their card back?" : "Did \(viewModel.targetName) show up?")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if isPetition {
                    Button {
                        viewModel.castVote(value: .yes)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Restore")
                        }
                    }
                    .buttonStyle(BlackoutButtonStyle(color: .successGreen))

                    Button {
                        viewModel.castVote(value: .no)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Deny")
                        }
                    }
                    .buttonStyle(BlackoutButtonStyle(color: .dangerRed))
                } else {
                    // For failure vote: "Yes" means they DID NOT show up (vote passes = penalty)
                    Button {
                        viewModel.castVote(value: .no)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("They Showed Up")
                        }
                    }
                    .buttonStyle(BlackoutButtonStyle(color: .successGreen))

                    Button {
                        viewModel.castVote(value: .yes)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text("No Show")
                        }
                    }
                    .buttonStyle(BlackoutButtonStyle(color: .dangerRed))
                }
            }

            Text("Your vote is final and cannot be changed")
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .glowingCardStyle()
    }

    // MARK: - Voted Confirmation

    private var votedConfirmation: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(.successGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vote Cast")
                    .font(.headline)
                    .foregroundColor(.successGreen)
                Text("Waiting for other members to vote...")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 16) {
            Text("Vote Tally")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("\(viewModel.yesCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(viewModel.voteCase?.caseType == .petition ? .successGreen : .dangerRed)
                    Text(viewModel.voteCase?.caseType == .petition ? "Restore" : "No Show")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: 4) {
                    Text("vs")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: 8) {
                    Text("\(viewModel.noCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(viewModel.voteCase?.caseType == .petition ? .dangerRed : .successGreen)
                    Text(viewModel.voteCase?.caseType == .petition ? "Deny" : "Showed Up")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                let total = max(viewModel.yesCount + viewModel.noCount, 1)
                let yesWidth = CGFloat(viewModel.yesCount) / CGFloat(total) * geometry.size.width

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(viewModel.voteCase?.caseType == .petition ? Color.dangerRed.opacity(0.3) : Color.successGreen.opacity(0.3))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(viewModel.voteCase?.caseType == .petition ? Color.successGreen : Color.dangerRed)
                        .frame(width: yesWidth, height: 12)
                }
            }
            .frame(height: 12)

            Text("\(viewModel.yesCount + viewModel.noCount) of \(viewModel.totalMembers) members voted")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .cardStyle()
    }

    // MARK: - Final Result

    private func finalResultSection(_ voteCase: VoteCase) -> some View {
        VStack(spacing: 12) {
            let passed = voteCase.result == .pass

            Image(systemName: passed ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(passed
                    ? (voteCase.caseType == .failure ? .dangerRed : .successGreen)
                    : (voteCase.caseType == .failure ? .successGreen : .dangerRed)
                )

            if voteCase.caseType == .failure {
                Text(passed ? "Vote Passed - Card Revoked" : "Vote Failed - Card Safe")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(passed
                    ? "\(viewModel.targetName) has lost their Blackout Card for this period."
                    : "\(viewModel.targetName) keeps their card status."
                )
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            } else {
                Text(passed ? "Petition Approved - Card Restored!" : "Petition Denied")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(passed
                    ? "\(viewModel.targetName) has had their Blackout Card restored."
                    : "\(viewModel.targetName)'s petition was denied by the group."
                )
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            }
        }
        .glowingCardStyle(color: voteCase.result == .pass
            ? (voteCase.caseType == .failure ? .dangerRed : .successGreen)
            : .surfaceMedium
        )
    }
}
