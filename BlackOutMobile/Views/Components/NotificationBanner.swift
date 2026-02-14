import SwiftUI

struct NotificationBanner: View {
    let notification: AppNotification
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Dismiss
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.surfaceDark.opacity(0.85))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }

    private var iconName: String {
        switch notification.notificationType {
        case .cardPulled: return "suit.spade.fill"
        case .voteStarted: return "exclamationmark.triangle.fill"
        case .voteResolved: return "checkmark.circle.fill"
        case .petitionStarted: return "arrow.counterclockwise"
        case .petitionResolved: return "checkmark.seal.fill"
        case .periodReset: return "arrow.clockwise"
        case .groupInvite: return "person.badge.plus"
        }
    }

    private var iconColor: Color {
        switch notification.notificationType {
        case .cardPulled: return .accentPurple
        case .voteStarted: return .dangerRed
        case .voteResolved: return .successGreen
        case .petitionStarted: return .warningAmber
        case .petitionResolved: return .successGreen
        case .periodReset: return .accentPurple
        case .groupInvite: return .accentPurple
        }
    }
}

// MARK: - Banner Overlay Modifier

struct BannerOverlay: ViewModifier {
    @ObservedObject var store = DataStore.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let notification = store.bannerNotification {
                    NotificationBanner(notification: notification) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            store.bannerNotification = nil
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(Animation.spring(response: 0.4, dampingFraction: 0.8), value: store.bannerNotification?.id)
                    .padding(.top, 8)
                    .zIndex(100)
                }
            }
    }
}

extension View {
    func withNotificationBanner() -> some View {
        modifier(BannerOverlay())
    }
}
