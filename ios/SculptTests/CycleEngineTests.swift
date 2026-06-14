import XCTest
@testable import Sculpt

/// Verifies the ported phase engine matches src/lib/cycle.ts behaviour.
final class CycleEngineTests: XCTestCase {
    private let days = ["d1", "d2", "d3", "d4", "d5"]

    private func log(_ day: String, _ phase: Phase, cycle: Int, at: String = "2026-01-01T10:00:00.000Z") -> CycleLogRow {
        CycleLogRow(programDayId: day, weekPhase: WeekIntensity(rawValue: phase.rawValue)!,
                    cycleNumber: cycle, completedAt: at, feelRating: 4)
    }

    func testFreshStart() {
        let s = CycleEngine.deriveCycleState(logs: [], orderedDayIds: days)
        XCTAssertEqual(s.cycle, 1)
        XCTAssertEqual(s.phase, .light)
        XCTAssertEqual(s.weekIndex, 1)
        XCTAssertEqual(s.nextDayId, "d1")
        XCTAssertFalse(s.weekClosable)
    }

    func testCycleFloorRespected() {
        let s = CycleEngine.deriveCycleState(logs: [], orderedDayIds: days, cycleFloor: 4)
        XCTAssertEqual(s.cycle, 4)
    }

    func testWeekClosableAtThree() {
        let logs = [log("d1", .light, cycle: 1), log("d2", .light, cycle: 1), log("d3", .light, cycle: 1)]
        let s = CycleEngine.deriveCycleState(logs: logs, orderedDayIds: days)
        XCTAssertEqual(s.phase, .light)
        XCTAssertTrue(s.weekClosable)
        XCTAssertEqual(s.doneDayIds.count, 3)
        XCTAssertTrue(["d4", "d5"].contains(s.nextDayId ?? ""))
    }

    func testFullLightWeekAdvancesToMedium() {
        let logs = days.map { log($0, .light, cycle: 1) }
        let s = CycleEngine.deriveCycleState(logs: logs, orderedDayIds: days)
        XCTAssertEqual(s.phase, .medium)
        XCTAssertEqual(s.weekIndex, 2)
    }

    func testClosingWeekEarlyAdvances() {
        let logs = [log("d1", .light, cycle: 1), log("d2", .light, cycle: 1), log("d3", .light, cycle: 1)]
        let closures = [WeekClosure(cycleNumber: 1, weekPhase: .light)]
        let s = CycleEngine.deriveCycleState(logs: logs, orderedDayIds: days, closures: closures)
        XCTAssertEqual(s.phase, .medium)
    }

    func testHardWeekCompleteRollsToNextCycle() {
        var logs = days.map { log($0, .light, cycle: 1) }
        logs += days.map { log($0, .medium, cycle: 1) }
        logs += days.map { log($0, .hard, cycle: 1) }
        let s = CycleEngine.deriveCycleState(logs: logs, orderedDayIds: days)
        XCTAssertEqual(s.cycle, 2)
        XCTAssertEqual(s.phase, .light)
        XCTAssertTrue(s.cycleJustCompleted)
        XCTAssertEqual(s.nextDayId, "d1")
    }

    func testNoDaysDoesNotLoopForever() {
        let s = CycleEngine.deriveCycleState(logs: [], orderedDayIds: [])
        XCTAssertEqual(s.cycle, 1)
        XCTAssertNil(s.nextDayId)
        XCTAssertFalse(s.cycleJustCompleted)
    }

    func testNextDayPrefersLeastRecentlyTrained() {
        // d1 trained long ago, d2 recently; both undone this week → d1 first.
        let logs = [
            log("d2", .light, cycle: 1, at: "2026-01-05T10:00:00.000Z"),
            log("d1", .medium, cycle: 0, at: "2025-12-01T10:00:00.000Z"),
        ]
        // Only d2 done in current light week; d1,d3,d4,d5 remain.
        let s = CycleEngine.deriveCycleState(logs: logs, orderedDayIds: days)
        XCTAssertEqual(s.phase, .light)
        // d1 has the oldest completion → it should be suggested before d3..d5.
        XCTAssertEqual(s.nextDayId, "d1")
    }

    func testSummarizeCycles() {
        let logs = days.map { log($0, .light, cycle: 1) } + [log("d1", .light, cycle: 2)]
        let summaries = CycleEngine.summarizeCycles(logs)
        XCTAssertEqual(summaries.first?.cycle, 2) // newest first
        XCTAssertEqual(summaries.last?.cycle, 1)
        XCTAssertEqual(summaries.last?.workouts, 5)
    }
}
