import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// The rest-timer Live Activity contract — shared by the app (which starts and
/// ends it) and the widget extension (which renders it on the Lock Screen and
/// in the Dynamic Island).
struct RestActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the rest interval ends — the UI uses a `Text(timerInterval:)`
        /// so it counts down on its own with no push updates.
        var endDate: Date
        /// The exercise waiting on the other side of the rest.
        var nextExercise: String
    }

    /// The day being trained — fixed for the life of the activity.
    var dayName: String
}
#endif
