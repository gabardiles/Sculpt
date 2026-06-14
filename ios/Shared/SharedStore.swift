import Foundation

/// A tiny bridge between the app and the widget extension. The app writes the
/// current "next session" snapshot; the widget reads it. Backed by an App Group
/// when one is configured (see README), and falls back to standard defaults so
/// nothing crashes if the group isn't set up yet — the widget just shows a
/// gentle placeholder until the capability is added.
enum SharedStore {
    static let appGroup = "group.com.sculpt.app"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
    private static let key = "next-session"

    struct NextSession: Codable {
        var dayName: String
        var headerLine: String   // e.g. "CYCLE 2 · WEEK 1 · LIGHT"
        var exercises: Int
        var progress: Double     // 0..1 across the current week
        var theme: String        // "sculpt" | "spartan"
    }

    static func writeNextSession(_ session: NextSession?) {
        guard let session, let data = try? JSONEncoder().encode(session) else {
            defaults.removeObject(forKey: key); return
        }
        defaults.set(data, forKey: key)
    }

    static func readNextSession() -> NextSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NextSession.self, from: data)
    }
}
