import XCTest
@testable import Sculpt

/// Verifies the fixed-schedule engine matches src/lib/schedule.ts.
final class ScheduleEngineTests: XCTestCase {
    private func week(_ idx: Int, _ intensity: WeekIntensity, _ dayIds: [String]) -> ScheduleWeek {
        ScheduleWeek(weekIndex: idx, intensity: intensity, label: nil, note: nil, dayIds: dayIds)
    }
    private func log(_ day: String) -> CycleLogRow {
        CycleLogRow(programDayId: day, weekPhase: .light, cycleNumber: 1,
                    completedAt: "2026-01-01T10:00:00.000Z", feelRating: nil)
    }

    private let weeks = [
        ScheduleWeek(weekIndex: 1, intensity: .light, label: nil, note: nil, dayIds: ["w1d1", "w1d2"]),
        ScheduleWeek(weekIndex: 2, intensity: .medium, label: nil, note: nil, dayIds: ["w2d1", "w2d2"]),
        ScheduleWeek(weekIndex: 3, intensity: .test, label: nil, note: nil, dayIds: ["w3d1"]),
    ]

    func testStartsAtWeekOne() {
        let s = ScheduleEngine.deriveScheduleState(weeks: weeks, logs: [])
        XCTAssertEqual(s.weekIndex, 1)
        XCTAssertEqual(s.intensity, .light)
        XCTAssertEqual(s.totalWeeks, 3)
        XCTAssertEqual(s.nextDayId, "w1d1")
        XCTAssertFalse(s.programComplete)
    }

    func testCompletingWeekOneAdvances() {
        let logs = [log("w1d1"), log("w1d2")]
        let s = ScheduleEngine.deriveScheduleState(weeks: weeks, logs: logs)
        XCTAssertEqual(s.weekIndex, 2)
        XCTAssertEqual(s.intensity, .medium)
        XCTAssertEqual(s.nextDayId, "w2d1")
    }

    func testClosureSkipsWeek() {
        let closures = [WeekClosure(cycleNumber: 1, weekPhase: .light)] // cycleNumber stores week_index
        let s = ScheduleEngine.deriveScheduleState(weeks: weeks, logs: [], closures: closures)
        XCTAssertEqual(s.weekIndex, 2)
    }

    func testProgramComplete() {
        let logs = [log("w1d1"), log("w1d2"), log("w2d1"), log("w2d2"), log("w3d1")]
        let s = ScheduleEngine.deriveScheduleState(weeks: weeks, logs: logs)
        XCTAssertTrue(s.programComplete)
        XCTAssertNil(s.nextDayId)
    }

    func testTestWeekMapsToHardPhase() {
        XCTAssertEqual(WeekIntensity.test.phase, .hard)
        XCTAssertEqual(ScheduleLabels.intensity[.test], "TEST")
        XCTAssertEqual(ScheduleLabels.intensity[.hard], "HEAVY")
    }
}
