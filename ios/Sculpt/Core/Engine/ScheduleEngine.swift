import Foundation

// Direct port of src/lib/schedule.ts — the fixed-schedule engine (Hybrid
// Athlete): distinct prescribed weeks instead of a repeating 3-week cycle.

enum ScheduleLabels {
    /// How the coach's intensity reads on screen — 'hard' is his HEAVY week.
    static let intensity: [WeekIntensity: String] = [
        .light: "LIGHT", .medium: "MEDIUM", .hard: "HEAVY", .test: "TEST",
    ]
    static let session: [SessionType: String] = [
        .strength: "Strength", .crossfit: "CrossFit", .conditioning: "Conditioning",
    ]
    static let weekday = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
}

struct ScheduleWeek: Sendable {
    var weekIndex: Int
    var intensity: WeekIntensity
    var label: String?
    var note: String?
    var dayIds: [String]   // ordered by day_index
}

struct ScheduleState: Equatable {
    var weekIndex: Int     // 1..totalWeeks
    var intensity: WeekIntensity
    var totalWeeks: Int
    var doneDayIds: Set<String>
    var nextDayId: String?
    var weekClosable: Bool
    var programComplete: Bool
}

enum ScheduleEngine {
    /// Current week = the first week whose sessions aren't all logged and that
    /// wasn't explicitly closed (closures store week_index in cycle_number).
    static func deriveScheduleState(
        weeks: [ScheduleWeek],
        logs: [CycleLogRow],
        closures: [WeekClosure] = []
    ) -> ScheduleState {
        let done = Set(logs.map(\.programDayId))
        let closed = Set(closures.map(\.cycleNumber))

        for week in weeks {
            let doneInWeek = week.dayIds.filter { done.contains($0) }
            let finished = doneInWeek.count >= week.dayIds.count
                || closed.contains(week.weekIndex)
                || week.dayIds.isEmpty
            if !finished {
                return ScheduleState(
                    weekIndex: week.weekIndex,
                    intensity: week.intensity,
                    totalWeeks: weeks.count,
                    doneDayIds: done,
                    nextDayId: week.dayIds.first { !done.contains($0) },
                    weekClosable: doneInWeek.count >= min(RepTargets.weekMinSessions, week.dayIds.count),
                    programComplete: false
                )
            }
        }

        let last = weeks.last
        return ScheduleState(
            weekIndex: last?.weekIndex ?? 1,
            intensity: last?.intensity ?? .light,
            totalWeeks: weeks.count,
            doneDayIds: done,
            nextDayId: nil,
            weekClosable: false,
            programComplete: !weeks.isEmpty
        )
    }
}
