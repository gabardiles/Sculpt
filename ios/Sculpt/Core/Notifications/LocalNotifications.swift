import Foundation
import UserNotifications

/// Local notifications — no Apple Developer account or APNs required. These are
/// scheduled on-device:
///  • the rest timer finishing while she's left the app mid-session, and
///  • gentle "time to train?" nudges after a few quiet days.
///
/// Server-driven push (a friend cheering while the app is closed) is a
/// separate thing — see PushNotifications.swift — and needs the paid account.
@MainActor
final class LocalNotifications {
    static let shared = LocalNotifications()
    private let center = UNUserNotificationCenter.current()

    private let restId = "sculpt.rest-timer"
    private let reminderPrefix = "sculpt.reminder."

    /// Whether the member opted into training-reminder nudges (default on).
    var remindersEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "sculpt-reminders") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "sculpt-reminders")
            Task { newValue ? await scheduleTrainingReminders() : cancelTrainingReminders() }
        }
    }

    /// Ask once, politely. Safe to call on every launch.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Rest timer

    /// Buzz when the rest interval ends, even from the background. Cancelled if
    /// she dismisses rest or marks the next set first.
    func scheduleRestEnd(at fireDate: Date, nextName: String?) {
        let seconds = fireDate.timeIntervalSinceNow
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest's over"
        content.body = nextName.map { "Next up: \($0)" } ?? "Back to it."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: restId, content: content, trigger: trigger))
    }

    func cancelRestEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [restId])
    }

    // MARK: Training reminders

    /// A quiet nudge each evening at 18:00, for the next several days, so an
    /// abandoned week doesn't slip by unnoticed. Re-armed whenever the app
    /// opens (and pushed back every time she actually trains — call
    /// `bumpAfterWorkout()`).
    func scheduleTrainingReminders() async {
        guard remindersEnabled else { return }
        cancelTrainingReminders()
        let messages = [
            "Your program's waiting. One session is enough.",
            "Three of five completes the week — fancy one now?",
            "Small and consistent wins. Today's a good day to lift.",
        ]
        var comps = DateComponents(); comps.hour = 18; comps.minute = 0
        let cal = Calendar.current
        // Start two days out so we never nag the same day she trained.
        for offset in 2...4 {
            guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
            var c = cal.dateComponents([.year, .month, .day], from: day)
            c.hour = 18; c.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "Sculpt"
            content.body = messages[(offset - 2) % messages.count]
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(reminderPrefix)\(offset)", content: content, trigger: trigger))
        }
    }

    func cancelTrainingReminders() {
        let ids = (2...7).map { "\(reminderPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// After logging a session, push the reminders out fresh.
    func bumpAfterWorkout() {
        Task { await scheduleTrainingReminders() }
    }
}
