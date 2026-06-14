import Foundation
import WidgetKit

/// Loads the dashboard's data and derives the week state with the same engines
/// the web app uses. Mirrors the heavy server component in src/app/(app)/page.tsx.
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var loading = true
    @Published var profile: Profile?
    @Published var program: ProgramWithDays?
    @Published var quote: Quote?

    // Derived
    @Published var headerLine = ""
    @Published var nextDay: DayWithExercises?
    @Published var weekDays: [DayRowItem] = []
    @Published var phase: Phase = .light
    @Published var weekComplete = false
    @Published var sessionsThisWeek = 0
    @Published var weekVolume = 0.0
    @Published var avgFeel: Double?
    @Published var volumeSpark: [Double] = []
    @Published var report: FitnessReport?
    @Published var goalRows: [GoalRowItem] = []
    @Published var weekProgress = 0.0

    struct DayRowItem: Identifiable {
        let id: String
        let index: Int
        let name: String
        let done: Bool
        let doneAt: String?
    }
    struct GoalRowItem: Identifiable {
        let id: String
        let label: String
        let progress: Double
        let hit: Bool
    }

    private let repo = Repository.shared

    func load() async {
        loading = true
        guard let userId = await repo.currentUserId() else { loading = false; return }
        do {
            async let p = repo.getProfile(userId)
            async let prog = repo.getActiveProgram(userId)
            async let q = repo.getQuoteOfTheDay()
            async let rep = repo.getLatestFitnessReport(userId)
            self.profile = try await p
            self.quote = try await q
            self.report = try await rep
            guard let program = try await prog else { loading = false; return }
            self.program = program

            let dayIds = program.orderedDayIds
            async let logsA = repo.getCycleLogs(userId, dayIds: dayIds)
            async let closuresA = repo.getWeekClosures(userId)
            async let goalsA = repo.getGoals(userId)
            async let bwA = repo.getBodyWeights(userId)
            let logs = try await logsA
            let closures = try await closuresA
            let goals = try await goalsA
            let bodyWeights = try await bwA

            let exerciseIds = Array(Set(program.days.flatMap { $0.exercises.map(\.exerciseId) }))
            let setHistory = (try? await repo.getSetHistory(userId, exerciseIds: exerciseIds)) ?? []

            compute(program: program, logs: logs, closures: closures, goals: goals,
                    bodyWeights: bodyWeights, setHistory: setHistory)
        } catch {
            // Leave whatever loaded; the UI degrades gracefully.
        }
        loading = false
    }

    private func compute(program: ProgramWithDays, logs: [CycleLogRow], closures: [WeekClosure],
                         goals: [Goal], bodyWeights: [BodyWeight], setHistory: [SetHistoryRow]) {
        let fixed = program.program.scheduleMode == .fixed

        var doneIds = Set<String>()
        var nextId: String?

        if fixed {
            let weeks: [ScheduleWeek] = program.weekPlan.map { w in
                ScheduleWeek(weekIndex: w.weekIndex, intensity: w.intensity, label: w.label, note: w.note,
                             dayIds: program.days.filter { $0.day.weekIndex == w.weekIndex }.map(\.day.id))
            }
            let s = ScheduleEngine.deriveScheduleState(weeks: weeks, logs: logs, closures: closures)
            doneIds = s.doneDayIds
            nextId = s.nextDayId
            phase = s.intensity.phase
            weekComplete = s.programComplete || s.nextDayId == nil
            headerLine = "WEEK \(s.weekIndex) OF \(s.totalWeeks) · \(ScheduleLabels.intensity[s.intensity] ?? "")"
            let weekDayModels = program.days.filter { $0.day.weekIndex == s.weekIndex }
            buildDayRows(weekDayModels, doneIds: doneIds, nextId: nextId, fixed: true)
            weekProgress = weekDayModels.isEmpty ? 0
                : Double(weekDayModels.filter { doneIds.contains($0.day.id) }.count) / Double(weekDayModels.count)
        } else {
            let s = CycleEngine.deriveCycleState(logs: logs, orderedDayIds: program.orderedDayIds,
                                                 cycleFloor: program.program.cycleFloor, closures: closures)
            doneIds = s.doneDayIds
            nextId = s.nextDayId
            phase = s.phase
            weekComplete = s.nextDayId == nil
            headerLine = "CYCLE \(s.cycle) · WEEK \(s.weekIndex) · \(s.phase.rawValue.uppercased())"
            buildDayRows(program.days, doneIds: doneIds, nextId: nextId, fixed: false)
            weekProgress = program.orderedDayIds.isEmpty ? 0
                : Double(doneIds.count) / Double(program.orderedDayIds.count)
        }
        nextDay = program.days.first { $0.day.id == nextId }

        // This-week numbers + volume spark.
        let weekAgo = Date().addingTimeInterval(-7 * 86_400).timeIntervalSince1970
        let thisWeek = logs.filter { (Fmt.parseISO($0.completedAt)?.timeIntervalSince1970 ?? 0) > weekAgo }
        sessionsThisWeek = thisWeek.count
        let feels = thisWeek.compactMap(\.feelRating).map(Double.init)
        avgFeel = feels.isEmpty ? nil : feels.reduce(0, +) / Double(feels.count)

        // Volume per session = Σ weight × reps × sets.
        var volBySession: [String: (at: String, vol: Double)] = [:]
        for s in setHistory {
            let key = s.workoutLog.completedAt
            var e = volBySession[key] ?? (at: s.workoutLog.completedAt, vol: 0)
            if let w = s.weightKg, let r = s.reps {
                e.vol += w * Double(r) * Double(s.sets ?? RepTargets.setsPerExercise)
            }
            volBySession[key] = e
        }
        let sessions = volBySession.values.sorted { $0.at < $1.at }
        volumeSpark = sessions.suffix(8).map(\.vol)
        weekVolume = sessions.filter { (Fmt.parseISO($0.at)?.timeIntervalSince1970 ?? 0) > weekAgo }
            .reduce(0) { $0 + $1.vol }

        // Goals (up to 3 active).
        var prByExercise: [String: Double] = [:]
        for s in setHistory {
            guard let w = s.weightKg else { continue }
            if w > (prByExercise[s.exerciseId] ?? 0) { prByExercise[s.exerciseId] = w }
        }
        let ctx = GoalContext(
            latestBodyWeight: bodyWeights.last?.weightKg,
            prByExercise: prByExercise,
            workoutDates: logs.map(\.completedAt),
            latestFitnessScore: (report?.assessable == true) ? report?.overallScore : nil
        )
        goalRows = goals.filter { !$0.achieved }.prefix(3).map { g in
            let p = GoalMath.compute(g, ctx)
            return GoalRowItem(id: g.id, label: GoalMath.label(g), progress: p.progress, hit: p.hit)
        }

        updateWidgetSnapshot()
    }

    /// Push the "next session" snapshot to the shared store so the home-screen
    /// widget reflects the current week. Cheap and idempotent.
    private func updateWidgetSnapshot() {
        let snapshot = SharedStore.NextSession(
            dayName: nextDay?.day.name ?? "Week complete",
            headerLine: headerLine,
            exercises: nextDay?.exercises.count ?? 0,
            progress: weekComplete ? 1 : weekProgress,
            theme: profile?.theme?.rawValue ?? "sculpt"
        )
        SharedStore.writeNextSession(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func buildDayRows(_ days: [DayWithExercises], doneIds: Set<String>, nextId: String?, fixed: Bool) {
        let byDay: [String: String] = Dictionary(
            // most-recent completion per day is fine for the row subtitle
            days.map { ($0.day.id, "") }, uniquingKeysWith: { a, _ in a })
        _ = byDay
        weekDays = days
            .filter { $0.day.id != nextId }   // hero already shows the next day
            .map { d in
                let name: String
                if fixed, let wd = d.day.weekday {
                    name = "\(ScheduleLabels.weekday[wd - 1]) · \(d.day.name)"
                } else { name = d.day.name }
                return DayRowItem(id: d.day.id, index: d.day.dayIndex, name: name,
                                  done: doneIds.contains(d.day.id), doneAt: nil)
            }
    }
}
