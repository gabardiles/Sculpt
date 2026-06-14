import WidgetKit
import SwiftUI

/// Home- and Lock-Screen widget: the next session at a glance, with this week's
/// progress. Reads the snapshot the app writes to the shared App Group.
struct NextSessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextSessionWidget", provider: NextSessionProvider()) { entry in
            NextSessionView(entry: entry)
                .containerBackground(WidgetPalette.bg(entry.session?.theme ?? "sculpt"), for: .widget)
        }
        .configurationDisplayName("Next session")
        .description("Your next Sculpt workout and this week's progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct NextSessionEntry: TimelineEntry {
    let date: Date
    let session: SharedStore.NextSession?
}

struct NextSessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextSessionEntry {
        NextSessionEntry(date: .now, session: .init(dayName: "Glutes & Hamstrings",
            headerLine: "CYCLE 1 · WEEK 1 · LIGHT", exercises: 5, progress: 0.4, theme: "sculpt"))
    }
    func getSnapshot(in context: Context, completion: @escaping (NextSessionEntry) -> Void) {
        completion(NextSessionEntry(date: .now, session: SharedStore.readNextSession()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextSessionEntry>) -> Void) {
        let entry = NextSessionEntry(date: .now, session: SharedStore.readNextSession())
        // Refresh hourly; the app also nudges WidgetCenter on every change.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct NextSessionView: View {
    var entry: NextSessionEntry
    @Environment(\.widgetFamily) private var family

    private var theme: String { entry.session?.theme ?? "sculpt" }

    var body: some View {
        if family == .accessoryRectangular {
            accessory
        } else {
            full
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NEXT SESSION").font(.system(size: 10, design: .monospaced))
            Text(entry.session?.dayName ?? "Open Sculpt").font(.headline).lineLimit(1)
            if let s = entry.session {
                ProgressView(value: s.progress).tint(.primary)
            }
        }
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEXT UP")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(WidgetPalette.inkSoft(theme))
            Spacer(minLength: 0)
            Text(entry.session?.dayName ?? "Open Sculpt")
                .font(.system(size: family == .systemSmall ? 19 : 24, weight: .light))
                .foregroundStyle(WidgetPalette.ink(theme))
                .lineLimit(2)
            if let s = entry.session {
                Text("\(s.exercises) exercises")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(WidgetPalette.inkSoft(theme))
                ProgressView(value: s.progress)
                    .tint(WidgetPalette.accent(theme))
                Text(s.headerLine)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(WidgetPalette.inkSoft(theme))
                    .lineLimit(1)
            } else {
                Text("Tap to start training")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetPalette.inkSoft(theme))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
