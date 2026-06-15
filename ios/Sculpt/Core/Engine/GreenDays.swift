import Foundation

// The "Green Days" gamification layer. Ported 1:1 to src/lib/greenDays.ts so
// iOS and web agree on every verdict, point and streak.
//
//   Green = trained OR hit the step goal that day.
//   Gold  = trained AND hit the step goal (a bonus on top).
//
// Everything below is pure: feed it the day rows and it derives state, points,
// streaks, level and milestones. No clock reads except the `today` you pass in.

/// One member-day, mirroring the `activity_days` row.
struct ActivityDay: Codable, Sendable, Identifiable {
    var userId: String?
    var date: String          // yyyy-MM-dd
    var steps: Int
    var stepGoal: Int
    var workoutDone: Bool

    var id: String { (userId ?? "") + date }

    enum State: String, Codable, Sendable { case none, green, gold }

    var stepGoalHit: Bool { stepGoal > 0 && steps >= stepGoal }

    var state: State {
        if workoutDone && stepGoalHit { return .gold }
        if workoutDone || stepGoalHit { return .green }
        return .none
    }

    /// Workout 100 · step goal 50 · both-in-a-day bonus 25.
    var points: Int {
        var p = 0
        if workoutDone { p += GreenDays.workoutPoints }
        if stepGoalHit { p += GreenDays.stepPoints }
        if state == .gold { p += GreenDays.goldBonus }
        return p
    }
}

/// Aggregate streak/points picture for one member.
struct GreenSummary: Sendable, Equatable {
    var currentStreak = 0
    var longestStreak = 0
    var totalPoints = 0
    var greenDays = 0
    var goldDays = 0
    var levelIndex = 0
    var levelName = GreenDays.tiers[0].name
    var pointsIntoLevel = 0       // progress within the current tier
    var pointsForLevelSpan = 0    // size of the current tier (0 at max tier)
    var nextLevelName: String?    // nil at the top tier

    var levelProgress: Double {
        pointsForLevelSpan <= 0 ? 1 : min(1, Double(pointsIntoLevel) / Double(pointsForLevelSpan))
    }
}

enum GreenDays {
    static let workoutPoints = 100
    static let stepPoints = 50
    static let goldBonus = 25
    static let defaultStepGoal = 10_000

    struct Tier: Sendable { let name: String; let minPoints: Int }
    /// Fire-themed levels — reads well under both the Sculpt and Spartan palettes.
    static let tiers: [Tier] = [
        Tier(name: "Spark", minPoints: 0),
        Tier(name: "Ember", minPoints: 300),
        Tier(name: "Kindle", minPoints: 800),
        Tier(name: "Flame", minPoints: 1_600),
        Tier(name: "Blaze", minPoints: 3_200),
        Tier(name: "Wildfire", minPoints: 6_000),
    ]

    /// Streak lengths worth a badge.
    static let milestones = [3, 7, 14, 30, 60, 100]

    // MARK: - Derivations

    static func summary(_ days: [ActivityDay], today: String = Fmt.todayISO()) -> GreenSummary {
        var s = GreenSummary()
        let green = Set(days.filter { $0.state != .none }.map(\.date))
        s.greenDays = days.filter { $0.state == .green }.count
        s.goldDays = days.filter { $0.state == .gold }.count
        s.totalPoints = days.reduce(0) { $0 + $1.points }
        s.currentStreak = currentStreak(greenDates: green, today: today)
        s.longestStreak = longestStreak(greenDates: green)

        let lvl = level(forPoints: s.totalPoints)
        s.levelIndex = lvl.index
        s.levelName = tiers[lvl.index].name
        s.pointsIntoLevel = s.totalPoints - tiers[lvl.index].minPoints
        if lvl.index + 1 < tiers.count {
            s.pointsForLevelSpan = tiers[lvl.index + 1].minPoints - tiers[lvl.index].minPoints
            s.nextLevelName = tiers[lvl.index + 1].name
        }
        return s
    }

    static func level(forPoints points: Int) -> (index: Int, tier: Tier) {
        var idx = 0
        for (i, t) in tiers.enumerated() where points >= t.minPoints { idx = i }
        return (idx, tiers[idx])
    }

    /// Consecutive green days ending today — or yesterday, so a day that hasn't
    /// been earned *yet* doesn't prematurely break a live streak.
    static func currentStreak(greenDates: Set<String>, today: String) -> Int {
        guard let todayDate = parse(today) else { return 0 }
        var cursor = greenDates.contains(today)
            ? todayDate
            : addingDays(-1, to: todayDate)   // today still open — count from yesterday
        var streak = 0
        while greenDates.contains(iso(cursor)) {
            streak += 1
            cursor = addingDays(-1, to: cursor)
        }
        return streak
    }

    static func longestStreak(greenDates: Set<String>) -> Int {
        let sorted = greenDates.compactMap(parse).sorted()
        guard !sorted.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<sorted.count {
            if isNextDay(sorted[i - 1], sorted[i]) { run += 1 } else { run = 1 }
            best = max(best, run)
        }
        return best
    }

    // MARK: - Calendar date math (UTC, day-granular — matches yyyy-MM-dd keys)

    static let calendarUTC: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }()
    private static var cal: Calendar { calendarUTC }
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func parse(_ s: String) -> Date? { fmt.date(from: String(s.prefix(10))) }
    static func iso(_ d: Date) -> String { fmt.string(from: d) }
    static func addingDays(_ n: Int, to d: Date) -> Date {
        cal.date(byAdding: .day, value: n, to: d) ?? d
    }
    private static func isNextDay(_ a: Date, _ b: Date) -> Bool {
        cal.dateComponents([.day], from: a, to: b).day == 1
    }
}
