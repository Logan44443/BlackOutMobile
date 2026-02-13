import SwiftUI

struct NotificationsListView: View {
    @ObservedObject private var store = DataStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                let notifications = store.notificationsForCurrentUser()

                if notifications.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(notifications) { notification in
                                NotificationRowView(notification: notification) {
                                    store.markNotificationRead(notification.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.accentPurple)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Read All") {
                        store.markAllNotificationsRead()
                    }
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.surfaceMedium)
            Text("No Notifications")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("You're all caught up!")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Notification Row

struct NotificationRowView: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Text(notification.createdAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }

                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.accentPurple)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(12)
            .background(notification.isRead ? Color.surfaceDark : Color.surfaceDark.opacity(0.8))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        notification.isRead ? Color.clear : Color.accentPurple.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
    }

    private var iconName: String {
        switch notification.notificationType {
        case .cardPulled: return "suit.spade.fill"
        case .voteStarted: return "exclamationmark.triangle.fill"
        case .voteResolved: return "checkmark.circle.fill"
        case .petitionStarted: return "arrow.counterclockwise"
        case .petitionResolved: return "checkmark.seal.fill"
        case .periodReset: return "arrow.clockwise"
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
        }
    }
}
