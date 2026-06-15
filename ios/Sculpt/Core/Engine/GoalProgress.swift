import Foundation

// Ported from src/lib/goals.ts.

struct GoalContext {
    var latestBodyWeight: Double?
    var prByExercise: [String: Double]
    var workoutDates: [String]     // ISO strings
    var latestFitnessScore: Double?
}

struct GoalProgress {
    var progress: Double   // 0..1
    var current: String
    var target: String
    var hit: Bool
}

enum GoalMath {
    private static let consistencyWindowWeeks = 4

    static func compute(_ goal: Goal, _ ctx: GoalContext) -> GoalProgress {
        switch goal.type {
        case .bodyWeight:
            let current = ctx.latestBodyWeight
            let baseline = goal.baselineValue ?? current ?? goal.targetValue
            let target = goal.targetValue
            guard let current else {
                return GoalProgress(progress: 0, current: "—", target: "\(Fmt.kg(target)) kg", hit: false)
            }
            let total = abs(baseline - target)
            let travelled = abs(baseline - current)
            let rightDirection = baseline == target
                || (baseline > target ? current <= baseline : current >= baseline)
            let hit = baseline > target ? current <= target : current >= target
            let progress = hit ? 1.0 : (total == 0 ? 0 : (rightDirection ? min(1, travelled / total) : 0))
            return GoalProgress(progress: progress, current: "\(Fmt.kg(current)) kg",
                                target: "\(Fmt.kg(target)) kg", hit: hit)

        case .fitnessScore:
            let current = ctx.latestFitnessScore
            let target = goal.targetValue
            let baseline = goal.baselineValue ?? current ?? 0
            guard let current else {
                return GoalProgress(progress: 0, current: "—",
                                    target: String(format: "%.1f/10", target), hit: false)
            }
            let span = target - baseline
            let hit = current >= target
            let progress = hit ? 1.0 : (span <= 0 ? 0 : max(0, min(1, (current - baseline) / span)))
            return GoalProgress(progress: progress,
                                current: String(format: "%.1f/10", current),
                                target: String(format: "%.1f/10", target), hit: hit)

        case .exercisePR:
            let best = goal.exerciseId.flatMap { ctx.prByExercise[$0] } ?? 0
            return GoalProgress(progress: min(1, best / goal.targetValue),
                                current: "\(Fmt.kg(best)) kg",
                                target: "\(Fmt.kg(goal.targetValue)) kg",
                                hit: best >= goal.targetValue)

        case .consistency:
            let perWeek = goal.targetValue
            let now = Date().timeIntervalSince1970 * 1000
            var weeksHit = 0
            let dayMs = 86_400_000.0
            for w in 0..<consistencyWindowWeeks {
                let end = now - Double(w) * 7 * dayMs
                let start = end - 7 * dayMs
                let count = ctx.workoutDates.filter { iso in
                    guard let d = Fmt.parseISO(iso) else { return false }
                    let t = d.timeIntervalSince1970 * 1000
                    return t > start && t <= end
                }.count
                if Double(count) >= perWeek { weeksHit += 1 }
            }
            return GoalProgress(progress: Double(weeksHit) / Double(consistencyWindowWeeks),
                                current: "\(weeksHit)/\(consistencyWindowWeeks) wk",
                                target: "\(Int(perWeek))×/wk",
                                hit: weeksHit >= consistencyWindowWeeks)
        }
    }

    static func label(_ goal: Goal) -> String {
        switch goal.type {
        case .bodyWeight: return "Body weight"
        case .exercisePR: return goal.exercise?.shortLabel ?? goal.exercise?.name ?? "PR"
        case .consistency: return "Consistency"
        case .fitnessScore: return "Fitness score"
        }
    }
}
