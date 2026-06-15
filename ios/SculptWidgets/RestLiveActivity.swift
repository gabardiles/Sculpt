import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit

/// The rest-timer Live Activity — Lock Screen banner + Dynamic Island. The
/// countdown runs itself via `Text(timerInterval:)`, so no push updates are
/// needed while resting.
@available(iOS 16.1, *)
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            // Lock Screen / banner
            HStack(spacing: 14) {
                Image(systemName: "timer").font(.title2).foregroundStyle(Color(hex: "B97D77"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resting · \(context.attributes.dayName)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Next: \(context.state.nextExercise)")
                        .font(.headline).lineLimit(1)
                }
                Spacer()
                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 64)
            }
            .padding()
            .activityBackgroundTint(Color(hex: "FBF7F6"))
            .activitySystemActionForegroundColor(Color(hex: "2B2422"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer").font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.system(.title3, design: .monospaced))
                        .monospacedDigit()
                        .frame(width: 56)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Next: \(context.state.nextExercise)").font(.subheadline).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .monospacedDigit().frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
            }
            .keylineTint(Color(hex: "B97D77"))
        }
    }
}
#endif
