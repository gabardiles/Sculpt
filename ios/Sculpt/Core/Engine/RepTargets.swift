import Foundation

// Ported from src/lib/cycle.ts — rep targets are derived from phase + the
// exercise's rep profile, never stored. 3 sets, always.

enum RepTargets {
    static let phases: [Phase] = [.light, .medium, .hard]
    static let setsPerExercise = 3
    /// 3 of 5 sessions completes a week (checkbox). All 5 earns a star.
    static let weekMinSessions = 3

    private static let target: [RepProfile: [Phase: String]] = [
        .strength: [.light: "10–12", .medium: "6–8", .hard: "4–6"],
        .pump: [.light: "15–20", .medium: "12–15", .hard: "10–12"],
        .timed: [.light: "30 s", .medium: "40 s", .hard: "45 s"],
    ]

    private static let defaultReps: [RepProfile: [Phase: Int]] = [
        .strength: [.light: 12, .medium: 8, .hard: 6],
        .pump: [.light: 20, .medium: 15, .hard: 12],
        .timed: [.light: 30, .medium: 40, .hard: 45],
    ]

    // Unilaterals wave one notch higher than other compounds — a true 4–6RM
    // Bulgarian split squat is a coordination gamble, not a strength stimulus.
    private static let lungeTarget: [Phase: String] = [
        .light: "10–12", .medium: "8–10", .hard: "6–8",
    ]
    private static let lungeDefault: [Phase: Int] = [.light: 12, .medium: 10, .hard: 8]

    /// Rest timer defaults — hard weeks earn longer rest.
    static let restSeconds: [Phase: Int] = [.light: 90, .medium: 90, .hard: 120]

    static func repTarget(_ profile: RepProfile, _ pattern: MovementPattern, _ phase: Phase) -> String {
        if profile == .strength && pattern == .lunge { return lungeTarget[phase] ?? "" }
        return target[profile]?[phase] ?? ""
    }

    static func repDefault(_ profile: RepProfile, _ pattern: MovementPattern, _ phase: Phase) -> Int {
        if profile == .strength && pattern == .lunge { return lungeDefault[phase] ?? 0 }
        return defaultReps[profile]?[phase] ?? 0
    }
}
