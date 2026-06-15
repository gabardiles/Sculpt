import UIKit
import Supabase

/// Remote push for feed interactions ("Helena cheered your PB" while the app is
/// closed). This is the APP side: ask iOS for an APNs device token and store it
/// in Supabase so a server function can target it.
///
/// ⚠️ Requires the paid Apple Developer account: the Push Notifications
/// capability + an APNs auth key. Until that's in place, `enable()` is a no-op
/// that fails quietly (didFailToRegister) — everything below stays dormant and
/// harmless. The matching server piece lives in
/// supabase/functions/notify-feed/ and the device_tokens table migration.
@MainActor
final class PushNotifications {
    static let shared = PushNotifications()
    private let client = Supa.shared.client

    /// Call after the member is signed in and has granted notification
    /// permission. Safe to call when push isn't provisioned — it just no-ops.
    func enable() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// AppDelegate hands us the APNs token; persist it for this user so the
    /// Edge Function can push to her devices.
    func register(token: String) async {
        guard let userId = try? await client.auth.session.user.id.uuidString else { return }
        struct DeviceToken: Encodable {
            var userId: String; var token: String; var platform: String; var updatedAt: String
        }
        let row = DeviceToken(userId: userId, token: token, platform: "ios",
                              updatedAt: ISO8601DateFormatter().string(from: Date()))
        _ = try? await client.from("device_tokens")
            .upsert(row, onConflict: "token").execute()
    }
}
