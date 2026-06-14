import Foundation

// Direct port of src/lib/cycle.ts. State is derived from workout_logs, never
// stored: the current cycle is the highest cycle logged (or the program's
// manual reset floor), and the current week is the first unfinished phase.

struct CycleState: Equatable {
    var cycle: Int
    var phase: Phase
    var weekIndex: Int      // 1..3
    var doneDayIds: Set<String>
    var nextDayId: String?
    /// ≥3 sessions done — she may close the week and move on.
    var weekClosable: Bool
    /// True right after week 3 completes — the "cycle complete" moment.
    var cycleJustCompleted: Bool
}

struct CycleSummary: Equatable {
    var cycle: Int
    var start: String
    var end: String
    var workouts: Int
    var avgFeel: Double?
    var avgFeelByPhase: [Phase: Double]
}

enum CycleEngine {
    /// The whole phase engine. A week is finished when all days are logged OR
    /// it was explicitly closed (possible from 3/5 sessions). When the hard
    /// week finishes, the next cycle starts at light automatically.
    static func deriveCycleState(
        logs: [CycleLogRow],
        orderedDayIds: [String],
        cycleFloor: Int = 1,
        closures: [WeekClosure] = []
    ) -> CycleState {
        let maxLogged = logs.map(\.cycleNumber).max() ?? 0
        let cycle = max(maxLogged, cycleFloor, 1)

        // A program with no days would otherwise mark every phase "finished"
        // and loop the cycle counter forever.
        if orderedDayIds.isEmpty {
            return CycleState(
                cycle: cycle, phase: .light, weekIndex: 1, doneDayIds: [],
                nextDayId: nil, weekClosable: false, cycleJustCompleted: false
            )
        }

        let closed = Set(closures.map { "\($0.cycleNumber):\($0.weekPhase.rawValue)" })

        for (i, phase) in RepTargets.phases.enumerated() {
            let done = Set(
                logs.filter { $0.cycleNumber == cycle && $0.weekPhase.rawValue == phase.rawValue }
                    .map(\.programDayId)
            )
            let finished = done.count >= orderedDayIds.count
                || closed.contains("\(cycle):\(phase.rawValue)")
            if !finished {
                // Suggest the least-recently-trained day, not always Day 1 — if
                // she closes weeks at 3/5, the skipped days come first next week.
                var lastDoneAt: [String: String] = [:]
                for l in logs {
                    if let cur = lastDoneAt[l.programDayId] {
                        if l.completedAt > cur { lastDoneAt[l.programDayId] = l.completedAt }
                    } else {
                        lastDoneAt[l.programDayId] = l.completedAt
                    }
                }
                let nextDayId = orderedDayIds
                    .filter { !done.contains($0) }
                    .sorted { a, b in
                        let ta = lastDoneAt[a] ?? ""
                        let tb = lastDoneAt[b] ?? ""
                        if ta != tb { return ta < tb }   // never/oldest first
                        return (orderedDayIds.firstIndex(of: a) ?? 0) < (orderedDayIds.firstIndex(of: b) ?? 0)
                    }
                    .first
                return CycleState(
                    cycle: cycle, phase: phase, weekIndex: i + 1, doneDayIds: done,
                    nextDayId: nextDayId,
                    weekClosable: done.count >= RepTargets.weekMinSessions,
                    cycleJustCompleted: false
                )
            }
        }

        // All three weeks of the current cycle are done → roll into the next one.
        return CycleState(
            cycle: cycle + 1, phase: .light, weekIndex: 1, doneDayIds: [],
            nextDayId: orderedDayIds.first, weekClosable: false,
            cycleJustCompleted: true
        )
    }

    /// Previous cycles collapse into a quiet history list.
    static func summarizeCycles(_ logs: [CycleLogRow]) -> [CycleSummary] {
        var byCycle: [Int: [CycleLogRow]] = [:]
        for l in logs { byCycle[l.cycleNumber, default: []].append(l) }

        return byCycle
            .sorted { $0.key > $1.key }
            .map { cycle, rows in
                let dates = rows.map(\.completedAt).sorted()
                let feels = rows.compactMap(\.feelRating).map(Double.init)
                var avgFeelByPhase: [Phase: Double] = [:]
                for phase in RepTargets.phases {
                    let pf = rows.filter { $0.weekPhase.rawValue == phase.rawValue }
                        .compactMap(\.feelRating).map(Double.init)
                    if !pf.isEmpty { avgFeelByPhase[phase] = pf.reduce(0, +) / Double(pf.count) }
                }
                return CycleSummary(
                    cycle: cycle,
                    start: dates.first ?? "",
                    end: dates.last ?? "",
                    workouts: rows.count,
                    avgFeel: feels.isEmpty ? nil : feels.reduce(0, +) / Double(feels.count),
                    avgFeelByPhase: avgFeelByPhase
                )
            }
    }
}
