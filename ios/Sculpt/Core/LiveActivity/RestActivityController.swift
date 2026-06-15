import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Drives the rest-timer Live Activity from the workout screen. Entirely
/// best-effort: if Live Activities are unavailable or disabled, every call is a
/// no-op. Requires `NSSupportsLiveActivities = YES` in the app Info.plist (set)
/// and the widget extension that declares the `RestActivityAttributes` UI.
@MainActor
final class RestActivityController {
    static let shared = RestActivityController()

    #if canImport(ActivityKit)
    private var activity: Activity<RestActivityAttributes>?

    func start(dayName: String, endDate: Date, nextExercise: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end() // never run two at once
        let attributes = RestActivityAttributes(dayName: dayName)
        let state = RestActivityAttributes.ContentState(endDate: endDate, nextExercise: nextExercise)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate.addingTimeInterval(30))
            )
        } catch {
            // Throttled, disabled, or unsupported — fine, just skip it.
        }
    }

    func end() {
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
    #else
    func start(dayName: String, endDate: Date, nextExercise: String) {}
    func end() {}
    #endif
}
