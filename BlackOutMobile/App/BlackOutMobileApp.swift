import SwiftUI
import UIKit
import UserNotifications

@main
struct BlackOutMobileApp: App {
    @UIApplicationDelegateAdaptor(PushNotificationAppDelegate.self) var appDelegate
    @StateObject private var store = DataStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var cardPullVibrationTimer: Timer?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { updateCardPullVibrationTimer() }
        .onChange(of: store.unreadCardPulledCount) { updateCardPullVibrationTimer() }
    }

    /// When app is active and there are unread card-pull notifications, vibrate every 1.5s until they're cleared.
    private func updateCardPullVibrationTimer() {
        cardPullVibrationTimer?.invalidate()
        cardPullVibrationTimer = nil
        guard scenePhase == .active, store.unreadCardPulledCount > 0 else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        cardPullVibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if DataStore.shared.unreadCardPulledCount == 0 {
                timer.invalidate()
                return
            }
            generator.notificationOccurred(.error)
        }
        RunLoop.main.add(cardPullVibrationTimer!, forMode: .common)
    }
}

/// Handles push notification registration and device token; forwards token to DataStore for Supabase.
class PushNotificationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissionAndRegister(application: application)
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { @MainActor in
            await DataStore.shared.registerDeviceToken(tokenString)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("Push registration failed: \(error.localizedDescription)")
        #endif
    }

    private func requestNotificationPermissionAndRegister(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
