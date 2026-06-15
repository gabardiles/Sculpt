import Foundation

// Swift mirror of src/lib/types.ts. Dates are kept as ISO strings, exactly as
// the web app does, so the two clients share one mental model of the rows.
// The Supabase client is configured with convertFromSnakeCase, so Swift
// properties stay camelCase while the JSON stays snake_case.

// MARK: - Enums

enum Phase: String, Codable, CaseIterable, Sendable {
    case light, medium, hard
}

/// Week intensity for fixed-schedule programs — the phase vocabulary plus
/// 'test' (benchmark weeks). 'hard' renders as HEAVY in hybrid programs.
enum WeekIntensity: String, Codable, Sendable {
    case light, medium, hard, test

    /// Rep targets and rest timers key off Phase — test days train like heavy.
    var phase: Phase {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .hard, .test: return .hard
        }
    }
}

enum SessionType: String, Codable, Sendable {
    case strength, crossfit, conditioning
}

enum MovementPattern: String, Codable, Sendable {
    case hinge, squat, lunge, thrust, abduction, push, pull, core, accessory
}

enum GoalType: String, Codable, Sendable {
    case bodyWeight = "body_weight"
    case exercisePR = "exercise_pr"
    case consistency
    case fitnessScore = "fitness_score"
}

/// Training role — drives rep targets per phase and swap tiering.
enum RepProfile: String, Codable, Sendable {
    case strength, pump, timed
}

enum Gender: String, Codable, Sendable {
    case female, male, unspecified
}

enum AppTheme: String, Codable, Sendable {
    case sculpt, spartan
}

enum Unit: String, Codable, Sendable {
    case kg, s
}

// MARK: - Core rows

struct Profile: Codable, Identifiable, Sendable {
    let id: String
    var name: String?
    // Optional so partial profile selects (e.g. the friends feed, which fetches
    // only id/name/friend_code/theme) decode without a keyNotFound error.
    var isAdmin: Bool?
    var invitedBy: String?
    var friendCode: String?
    var theme: AppTheme?
    var gender: Gender?
    var age: Int?
    var heightCm: Double?
    var goalNote: String?
    var stepGoal: Int?
    var createdAt: String?
}

struct FitnessMetric: Codable, Identifiable, Sendable {
    var key: String
    var label: String
    var score: Double
    var comment: String
    var id: String { key }
}

struct FitnessReport: Codable, Identifiable, Sendable {
    let id: String
    var userId: String
    var assessable: Bool
    var overallScore: Double
    var level: String?
    var nextLevel: String?
    var metrics: [FitnessMetric]
    var strengths: [String]
    var focusAreas: [String]
    var focusMuscles: [String]
    var summary: String?
    var nextLevelAdvice: String?
    var bodyWeightKg: Double?
    var photoCount: Int
    var model: String?
    var createdAt: String
}

enum FeedPostType: String, Codable, Sendable {
    case workout, pb, photo, message
}

struct FeedPost: Codable, Identifiable, Sendable {
    let id: String
    var userId: String
    var type: FeedPostType
    var body: String?
    var storagePath: String?
    var metadata: JSONValue?
    var createdAt: String
}

struct Program: Codable, Identifiable, Sendable {
    let id: String
    var userId: String?
    var name: String
    var weeks: Int
    var daysPerWeek: Int
    var active: Bool
    var cycleFloor: Int
    var scheduleMode: ScheduleMode

    enum ScheduleMode: String, Codable, Sendable { case cycle, fixed }
}

struct ProgramWeek: Codable, Identifiable, Sendable {
    let id: String
    var programId: String
    var weekIndex: Int
    var intensity: WeekIntensity
    var label: String?
    var note: String?
}

struct ProgramDay: Codable, Identifiable, Sendable {
    let id: String
    var programId: String
    var dayIndex: Int
    var name: String
    var weekIndex: Int?
    var weekday: Int?
    var sessionType: SessionType
    var content: String?
}

struct Exercise: Codable, Identifiable, Sendable, Hashable {
    let id: String
    var name: String
    var shortLabel: String?
    var muscleGroup: String
    var movementPattern: MovementPattern
    var equipment: String?
    var instructionUrl: String?
    var cue: String?
    var imageUrl: String?
    var unit: Unit
    var repProfile: RepProfile
    var isGlobal: Bool

    static func == (lhs: Exercise, rhs: Exercise) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ProgramExercise: Codable, Identifiable, Sendable {
    let id: String
    var programDayId: String
    var exerciseId: String
    var sort: Int
    var sets: Int
    var scheme: String?
    var exercise: Exercise?
}

struct WorkoutLog: Codable, Identifiable, Sendable {
    let id: String
    var userId: String
    var programDayId: String
    var weekPhase: WeekIntensity
    var cycleNumber: Int
    var completedAt: String
    var feelRating: Int?
}

struct SetLog: Codable, Identifiable, Sendable {
    let id: String
    var workoutLogId: String
    var exerciseId: String
    var weightKg: Double?
    var reps: Int?
}

struct BodyWeight: Codable, Identifiable, Sendable {
    let id: String
    var userId: String
    var date: String
    var weightKg: Double
}

struct ProgressPhoto: Codable, Identifiable, Sendable {
    let id: String
    var userId: String
    var cycleNumber: Int
    var weekLabel: String
    var storagePath: String
    var createdAt: String
}

struct Goal: Codable, Identifiable, Sendable {
    let id: String
    var userId: String
    var type: GoalType
    var targetValue: Double
    var baselineValue: Double?
    var exerciseId: String?
    var deadline: String?
    var achieved: Bool
    var createdAt: String
    var exercise: Exercise?
}

struct Quote: Codable, Identifiable, Sendable {
    let id: String
    var text: String
    var author: String?
}
