import Foundation

/// Builds the workout screen's data exactly like the server page in
/// src/app/(app)/workout/[dayId]/page.tsx — the phase/cycle for this day plus
/// each exercise's "LAST: …" prefill, with the same-phase fallback.
@MainActor
final class WorkoutViewModel: ObservableObject {
    struct WorkoutExercise: Identifiable {
        let id: String           // exerciseId
        let programExerciseId: String
        let name: String
        let shortLabel: String?
        let muscleGroup: String
        let movementPattern: MovementPattern
        let equipment: String?
        let unit: Unit
        let repProfile: RepProfile
        let cue: String?
        let instructionUrl: String?
        let imageUrl: String?
        let sets: Int
        let scheme: String?
        let lastWeight: Double?
        let lastReps: Int?
        let lastSets: Int?
        let lastPhase: Phase?      // set when "last" came from a different phase
        let prevCycleWeight: Double?
    }

    struct Entry: Equatable { var weight: String; var reps: String; var sets: String; var done: Bool }

    @Published var exercises: [WorkoutExercise] = []
    @Published var entries: [String: Entry] = [:]
    @Published var phase: WeekIntensity = .light
    @Published var cycle = 1
    @Published var weekIndex = 1
    @Published var alreadyDone = false
    @Published var rationale: String?
    @Published var sharePrompt = ProgramCopy.sharePromptFallback
    @Published var fixedInfo: FixedInfo?
    @Published var loaded = false

    struct FixedInfo { let totalWeeks: Int; let intensityLabel: String; let sessionLabel: String; let content: String? }

    let day: DayWithExercises
    let program: ProgramWithDays?
    private let repo = Repository.shared

    init(day: DayWithExercises, program: ProgramWithDays?) {
        self.day = day; self.program = program
    }

    var repPhase: Phase { phase.phase }
    var doneCount: Int { entries.values.filter(\.done).count }
    var allDone: Bool { !exercises.isEmpty && doneCount == exercises.count }
    var nextUpId: String? { exercises.first { !(entries[$0.id]?.done ?? false) }?.id }

    func load() async {
        guard let program, let userId = await repo.currentUserId() else { return }
        let fixed = program.program.scheduleMode == .fixed
        let dayIds = program.orderedDayIds
        let exerciseIds = day.exercises.map(\.exerciseId)

        let logs = (try? await repo.getCycleLogs(userId, dayIds: dayIds)) ?? []
        // Use the dashboard-warmed history if it's still fresh, else fetch.
        let history: [SetHistoryRow]
        if let warm = WorkoutPrefetch.shared.take(dayId: day.day.id) {
            history = warm
        } else {
            history = (try? await repo.getSetHistory(userId, exerciseIds: exerciseIds)) ?? []
        }
        let closures = (try? await repo.getWeekClosures(userId)) ?? []

        if fixed {
            let weeks: [ScheduleWeek] = program.weekPlan.map { w in
                ScheduleWeek(weekIndex: w.weekIndex, intensity: w.intensity, label: w.label, note: w.note,
                             dayIds: program.days.filter { $0.day.weekIndex == w.weekIndex }.map(\.day.id))
            }
            let state = ScheduleEngine.deriveScheduleState(weeks: weeks, logs: logs, closures: closures)
            let ownWeek = program.weekPlan.first { $0.weekIndex == day.day.weekIndex }
            phase = ownWeek?.intensity ?? .light
            cycle = day.day.weekIndex ?? state.weekIndex
            weekIndex = cycle
            alreadyDone = state.doneDayIds.contains(day.day.id)
            fixedInfo = FixedInfo(
                totalWeeks: program.program.weeks,
                intensityLabel: ScheduleLabels.intensity[phase] ?? "",
                sessionLabel: ScheduleLabels.session[day.day.sessionType] ?? "",
                content: day.day.content)
        } else {
            let state = CycleEngine.deriveCycleState(logs: logs, orderedDayIds: dayIds,
                                                     cycleFloor: program.program.cycleFloor, closures: closures)
            phase = WeekIntensity(rawValue: state.phase.rawValue) ?? .light
            cycle = state.cycle
            weekIndex = state.weekIndex
            alreadyDone = state.doneDayIds.contains(day.day.id)
        }

        rationale = ProgramCopy.dayRationale[day.day.name]
        sharePrompt = ProgramCopy.sharePrompts[day.day.name] ?? ProgramCopy.sharePromptFallback

        exercises = day.exercises.map { pe in build(pe: pe, history: history, fixed: fixed) }
        entries = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, defaultEntry(for: $0)) })
        loaded = true
    }

    private func build(pe: ProgramExercise, history: [SetHistoryRow], fixed: Bool) -> WorkoutExercise {
        let ex = pe.exercise
        let allRows = history.filter { $0.exerciseId == pe.exerciseId }
            .sorted { $0.workoutLog.completedAt > $1.workoutLog.completedAt }
        let rows = fixed ? allRows : allRows.filter { $0.workoutLog.weekPhase == phase.rawValue }
        let last = rows.first ?? allRows.first
        let lastIsOtherPhase = !fixed && last != nil && last!.workoutLog.weekPhase != phase.rawValue
        let topCycle = rows.first?.workoutLog.cycleNumber ?? cycle
        let prevCycleRow = fixed ? nil : rows.first { $0.workoutLog.cycleNumber < topCycle }

        return WorkoutExercise(
            id: pe.exerciseId, programExerciseId: pe.id,
            name: ex?.name ?? "Exercise", shortLabel: ex?.shortLabel,
            muscleGroup: ex?.muscleGroup ?? "", movementPattern: ex?.movementPattern ?? .accessory,
            equipment: ex?.equipment, unit: ex?.unit ?? .kg, repProfile: ex?.repProfile ?? .pump,
            cue: ex?.cue, instructionUrl: ex?.instructionUrl, imageUrl: ex?.imageUrl,
            sets: pe.sets, scheme: pe.scheme,
            lastWeight: last?.weightKg, lastReps: last?.reps, lastSets: last?.sets,
            lastPhase: lastIsOtherPhase ? Phase(rawValue: last!.workoutLog.weekPhase) : nil,
            prevCycleWeight: prevCycleRow?.weightKg
        )
    }

    private func defaultEntry(for ex: WorkoutExercise) -> Entry {
        let weight: String
        if let w = ex.lastWeight { weight = Fmt.kg(w) }
        else if ex.unit == .s { weight = String(RepTargets.repDefault(.timed, .core, repPhase)) }
        else { weight = "" }
        let reps: String
        if ex.scheme != nil { reps = ex.lastReps.map(String.init) ?? "" }
        else if ex.unit == .s { reps = "" }
        else { reps = String(RepTargets.repDefault(ex.repProfile, ex.movementPattern, repPhase)) }
        return Entry(weight: weight, reps: reps, sets: String(ex.lastSets ?? ex.sets), done: false)
    }

    /// Should we nudge a load bump? Top of range hit last time.
    func suggestBump(_ ex: WorkoutExercise) -> String? {
        guard ex.scheme == nil, ex.unit == .kg, ex.lastWeight != nil,
              let lastReps = ex.lastReps,
              lastReps >= RepTargets.repDefault(ex.repProfile, ex.movementPattern, repPhase)
        else { return nil }
        return "Last time you hit the top of the range — try +\(ex.repProfile == .pump ? "1" : "2,5") kg"
    }

    func save(feel: Int) async -> Bool {
        guard let userId = await repo.currentUserId() else { return false }
        let payload: [Repository.WorkoutEntry] = exercises
            .filter { entries[$0.id]?.done == true }
            .map { ex in
                let e = entries[ex.id]!
                let w = Double(e.weight.replacingOccurrences(of: ",", with: "."))
                return Repository.WorkoutEntry(
                    exerciseId: ex.id,
                    weightKg: (w ?? 0) > 0 ? w : nil,
                    reps: Int(e.reps).flatMap { $0 > 0 ? $0 : nil },
                    sets: Int(e.sets).flatMap { $0 > 0 ? $0 : nil })
            }
        do {
            try await repo.completeWorkout(userId: userId, programDayId: day.day.id,
                                           phase: phase, cycle: cycle, feel: feel, entries: payload)
            WorkoutDraft.clear(dayId: day.day.id)
            return true
        } catch { return false }
    }
}

/// Local draft so leaving mid-session never costs inputs (mirrors the web's
/// localStorage draft). Keyed per day, ignored after a day.
enum WorkoutDraft {
    private static func key(_ id: String) -> String { "sculpt-workout-draft:\(id)" }
    private static let maxAge: TimeInterval = 24 * 60 * 60

    static func save(dayId: String, entries: [String: WorkoutViewModel.Entry]) {
        let dict = entries.mapValues { ["weight": $0.weight, "reps": $0.reps, "sets": $0.sets, "done": $0.done ? "1" : ""] }
        let payload: [String: Any] = ["at": Date().timeIntervalSince1970, "entries": dict]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            UserDefaults.standard.set(data, forKey: key(dayId))
        }
    }
    static func load(dayId: String) -> [String: WorkoutViewModel.Entry]? {
        guard let data = UserDefaults.standard.data(forKey: key(dayId)),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let at = obj["at"] as? TimeInterval, Date().timeIntervalSince1970 - at <= maxAge,
              let raw = obj["entries"] as? [String: [String: String]] else { return nil }
        return raw.mapValues {
            WorkoutViewModel.Entry(weight: $0["weight"] ?? "", reps: $0["reps"] ?? "",
                                   sets: $0["sets"] ?? "", done: ($0["done"] ?? "").isEmpty == false)
        }
    }
    static func clear(dayId: String) { UserDefaults.standard.removeObject(forKey: key(dayId)) }
}
