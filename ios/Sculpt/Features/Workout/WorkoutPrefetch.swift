import Foundation

/// A short-lived in-memory cache for the next workout's set history, warmed by
/// the dashboard so opening the session is instant (no "LAST: …" pop-in).
@MainActor
final class WorkoutPrefetch {
    static let shared = WorkoutPrefetch()
    private var cache: [String: (at: Date, history: [SetHistoryRow])] = [:]
    private let ttl: TimeInterval = 120

    func store(dayId: String, history: [SetHistoryRow]) {
        cache[dayId] = (Date(), history)
    }

    /// Returns warmed history once, if still fresh.
    func take(dayId: String) -> [SetHistoryRow]? {
        guard let e = cache[dayId], Date().timeIntervalSince(e.at) < ttl else { return nil }
        return e.history
    }
}
