import XCTest
@testable import Sculpt

/// Verifies goal progress (src/lib/goals.ts) and number formatting (format.ts).
final class GoalAndFormatTests: XCTestCase {

    private func goal(_ type: GoalType, target: Double, baseline: Double? = nil,
                      exerciseId: String? = nil) -> Goal {
        Goal(id: "g", userId: "u", type: type, targetValue: target, baselineValue: baseline,
             exerciseId: exerciseId, deadline: nil, achieved: false, createdAt: "2026-01-01", exercise: nil)
    }
    private var emptyCtx: GoalContext {
        GoalContext(latestBodyWeight: nil, prByExercise: [:], workoutDates: [], latestFitnessScore: nil)
    }

    func testBodyWeightLossProgress() {
        // baseline 70 → target 65; now 67.5 → halfway.
        let g = goal(.bodyWeight, target: 65, baseline: 70)
        var ctx = emptyCtx; ctx.latestBodyWeight = 67.5
        let p = GoalMath.compute(g, ctx)
        XCTAssertEqual(p.progress, 0.5, accuracy: 0.001)
        XCTAssertFalse(p.hit)
    }

    func testBodyWeightHit() {
        let g = goal(.bodyWeight, target: 65, baseline: 70)
        var ctx = emptyCtx; ctx.latestBodyWeight = 64
        let p = GoalMath.compute(g, ctx)
        XCTAssertEqual(p.progress, 1.0)
        XCTAssertTrue(p.hit)
    }

    func testExercisePR() {
        let g = goal(.exercisePR, target: 100, exerciseId: "ex1")
        var ctx = emptyCtx; ctx.prByExercise = ["ex1": 80]
        let p = GoalMath.compute(g, ctx)
        XCTAssertEqual(p.progress, 0.8, accuracy: 0.001)
        XCTAssertFalse(p.hit)
    }

    func testFitnessScoreClimb() {
        // baseline 5 → target 7; now 6 → 50%.
        let g = goal(.fitnessScore, target: 7, baseline: 5)
        var ctx = emptyCtx; ctx.latestFitnessScore = 6
        let p = GoalMath.compute(g, ctx)
        XCTAssertEqual(p.progress, 0.5, accuracy: 0.001)
    }

    func testConsistencyCountsRecentWeeks() {
        // Two workouts this week, target 2×/wk → this week counts.
        let now = Date()
        let iso = ISO8601DateFormatter()
        let recent = [iso.string(from: now.addingTimeInterval(-86_400)),
                      iso.string(from: now.addingTimeInterval(-2 * 86_400))]
        let g = goal(.consistency, target: 2)
        var ctx = emptyCtx; ctx.workoutDates = recent
        let p = GoalMath.compute(g, ctx)
        XCTAssertGreaterThanOrEqual(p.progress, 0.25) // at least 1 of 4 weeks hit
    }

    func testKgFormatting() {
        XCTAssertEqual(Fmt.kg(40), "40")
        XCTAssertEqual(Fmt.kg(12.5), "12,5")
        XCTAssertEqual(Fmt.kg(nil), "—")
    }

    func testRepTargets() {
        XCTAssertEqual(RepTargets.repTarget(.strength, .squat, .hard), "4–6")
        XCTAssertEqual(RepTargets.repTarget(.strength, .lunge, .hard), "6–8") // unilateral one notch up
        XCTAssertEqual(RepTargets.repTarget(.pump, .accessory, .light), "15–20")
        XCTAssertEqual(RepTargets.restSeconds[.hard], 120)
    }
}
