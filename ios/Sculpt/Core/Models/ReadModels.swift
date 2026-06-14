import Foundation

// Nested-read shapes (mirror src/lib/data.ts) plus the engine input rows
// (mirror src/lib/cycle.ts). Kept separate from the flat row models.

/// Minimal log row the cycle/schedule engines run on.
struct CycleLogRow: Codable, Sendable {
    var programDayId: String
    var weekPhase: WeekIntensity
    var cycleNumber: Int
    var completedAt: String
    var feelRating: Int?
}

struct WeekClosure: Codable, Sendable {
    var cycleNumber: Int
    var weekPhase: WeekIntensity
}

/// Per-exercise set history with the phase/cycle it was logged under.
struct SetHistoryRow: Codable, Sendable {
    var exerciseId: String
    var weightKg: Double?
    var reps: Int?
    var sets: Int?
    var workoutLog: Inner

    struct Inner: Codable, Sendable {
        var weekPhase: String
        var cycleNumber: Int
        var completedAt: String
    }
}

// MARK: - Active program (flattened from the nested select)

struct DayWithExercises: Identifiable, Sendable {
    let day: ProgramDay
    /// Each carries its joined `exercise`.
    let exercises: [ProgramExercise]
    var id: String { day.id }
}

struct ProgramWithDays: Sendable {
    let program: Program
    let days: [DayWithExercises]
    /// Fixed-schedule programs only — empty for cycle programs.
    let weekPlan: [ProgramWeek]

    /// Day ids in schedule order — the engines' `orderedDayIds`.
    var orderedDayIds: [String] { days.map { $0.day.id } }
}

// MARK: - Raw decode nodes for the nested PostgREST select

struct ProgramFetch: Decodable {
    let id: String
    let userId: String?
    let name: String
    let weeks: Int
    let daysPerWeek: Int
    let active: Bool
    let cycleFloor: Int
    let scheduleMode: Program.ScheduleMode?
    let programWeeks: [ProgramWeek]?
    let programDays: [DayFetch]?

    struct DayFetch: Decodable {
        let id: String
        let programId: String
        let dayIndex: Int
        let name: String
        let weekIndex: Int?
        let weekday: Int?
        let sessionType: SessionType?
        let content: String?
        let programExercises: [PEFetch]?
    }

    struct PEFetch: Decodable {
        let id: String
        let programDayId: String
        let exerciseId: String
        let sort: Int
        let sets: Int
        let scheme: String?
        let exercise: Exercise?
    }

    /// Flatten + sort exactly as getActiveProgram() does in data.ts.
    func flatten() -> ProgramWithDays {
        let program = Program(
            id: id, userId: userId, name: name, weeks: weeks,
            daysPerWeek: daysPerWeek, active: active, cycleFloor: cycleFloor,
            scheduleMode: scheduleMode ?? .cycle
        )
        let weekPlan = (programWeeks ?? []).sorted { $0.weekIndex < $1.weekIndex }
        let days = (programDays ?? [])
            .sorted {
                ($0.weekIndex ?? 0, $0.dayIndex) < ($1.weekIndex ?? 0, $1.dayIndex)
            }
            .map { d -> DayWithExercises in
                let day = ProgramDay(
                    id: d.id, programId: d.programId, dayIndex: d.dayIndex,
                    name: d.name, weekIndex: d.weekIndex, weekday: d.weekday,
                    sessionType: d.sessionType ?? .strength, content: d.content
                )
                let exercises = (d.programExercises ?? [])
                    .sorted { $0.sort < $1.sort }
                    .map {
                        ProgramExercise(
                            id: $0.id, programDayId: $0.programDayId,
                            exerciseId: $0.exerciseId, sort: $0.sort,
                            sets: $0.sets, scheme: $0.scheme, exercise: $0.exercise
                        )
                    }
                return DayWithExercises(day: day, exercises: exercises)
            }
        return ProgramWithDays(program: program, days: days, weekPlan: weekPlan)
    }
}
