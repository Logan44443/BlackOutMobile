import SwiftUI
import Combine

struct CountdownTimerView: View {
    let deadline: Date
    var compact: Bool = false

    @State private var timeRemaining: TimeInterval = 0
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        SwiftUI.Group {
            if compact {
                compactView
            } else {
                fullView
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timerCancellable?.cancel() }
    }

    // MARK: - Compact View

    private var compactView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.caption2)
            Text(timeRemaining.countdownFormatted)
                .font(.caption.monospaced())
        }
        .foregroundColor(urgencyColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(urgencyColor.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Full View

    private var fullView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.subheadline)
                Text("Time Remaining")
                    .font(.subheadline)
            }
            .foregroundColor(.textSecondary)

            Text(timeRemaining.countdownFormatted)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(urgencyColor)

            Text(timeRemaining.humanReadable)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        updateTime()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updateTime()
            }
    }

    private func updateTime() {
        timeRemaining = max(0, deadline.timeIntervalSince(Date()))
    }

    private var urgencyColor: Color {
        if timeRemaining <= 0 {
            return .textSecondary
        } else if timeRemaining < 3600 { // Less than 1 hour
            return .dangerRed
        } else if timeRemaining < 7200 { // Less than 2 hours
            return .warningAmber
        } else {
            return .accentPurple
        }
    }
}
