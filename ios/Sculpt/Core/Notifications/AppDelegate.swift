import UIKit
import UserNotifications

/// App delegate — owns notification presentation. It's also where remote-push
/// device-token callbacks will land once the Apple Developer account is set up
/// (see PushNotifications.swift); those hooks are present but inert until then.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show banners + play sound even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: Remote push (inert until APNs is configured — feature #2)

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        // Feature #2 (push) consumes this. Until then, just hold onto it.
        UserDefaults.standard.set(token, forKey: "sculpt-apns-token")
        Task { await PushNotifications.shared.register(token: token) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No APNs entitlement yet (no paid account) — expected. Ignore quietly.
    }
}
