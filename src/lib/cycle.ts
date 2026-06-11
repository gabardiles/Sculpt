import type { Phase } from "./types";

export const PHASES: Phase[] = ["light", "medium", "hard"];

/** Rep targets are derived from phase, never stored. 3 sets, always. */
export const REP_TARGETS: Record<Phase, string> = {
  light: "10–12",
  medium: "6–8",
  hard: "4–6",
};

/** Prefill value for the reps field (top of the phase range). */
export const REP_DEFAULT: Record<Phase, number> = {
  light: 12,
  medium: 8,
  hard: 6,
};

/** Rest timer defaults — hard weeks earn longer rest. */
export const REST_SECONDS: Record<Phase, number> = {
  light: 90,
  medium: 90,
  hard: 120,
};

export const SETS_PER_EXERCISE = 3;

export interface CycleLogRow {
  program_day_id: string;
  week_phase: Phase;
  cycle_number: number;
  completed_at: string;
  feel_rating: number | null;
}

export interface CycleState {
  cycle: number;
  phase: Phase;
  weekIndex: number; // 1..3
  doneDayIds: Set<string>; // days completed in the current cycle + phase
  nextDayId: string | null;
  /** True right after week 3 completes — the "cycle complete" moment. */
  cycleJustCompleted: boolean;
}

/**
 * The whole phase engine. State is derived from workout_logs, never stored:
 * the current cycle is the highest cycle logged (or the program's manual
 * reset floor), and the current week is the first phase with unfinished days.
 * When hard week completes, the next cycle starts at light automatically.
 */
export function deriveCycleState(
  logs: CycleLogRow[],
  orderedDayIds: string[],
  cycleFloor = 1
): CycleState {
  const maxLogged = logs.length
    ? Math.max(...logs.map((l) => l.cycle_number))
    : 0;
  const cycle = Math.max(maxLogged, cycleFloor, 1);

  for (let i = 0; i < PHASES.length; i++) {
    const phase = PHASES[i];
    const done = new Set(
      logs
        .filter((l) => l.cycle_number === cycle && l.week_phase === phase)
        .map((l) => l.program_day_id)
    );
    if (done.size < orderedDayIds.length) {
      return {
        cycle,
        phase,
        weekIndex: i + 1,
        doneDayIds: done,
        nextDayId: orderedDayIds.find((id) => !done.has(id)) ?? null,
        cycleJustCompleted: false,
      };
    }
  }

  // All three weeks of the current cycle are done → roll into the next one.
  return {
    cycle: cycle + 1,
    phase: "light",
    weekIndex: 1,
    doneDayIds: new Set(),
    nextDayId: orderedDayIds[0] ?? null,
    cycleJustCompleted: true,
  };
}

export interface CycleSummary {
  cycle: number;
  start: string;
  end: string;
  workouts: number;
  avgFeel: number | null;
  avgFeelByPhase: Partial<Record<Phase, number>>;
}

/** Previous cycles collapse into a quiet history list. */
export function summarizeCycles(logs: CycleLogRow[]): CycleSummary[] {
  const byCycle = new Map<number, CycleLogRow[]>();
  for (const l of logs) {
    const arr = byCycle.get(l.cycle_number) ?? [];
    arr.push(l);
    byCycle.set(l.cycle_number, arr);
  }
  return [...byCycle.entries()]
    .sort((a, b) => b[0] - a[0])
    .map(([cycle, rows]) => {
      const dates = rows.map((r) => r.completed_at).sort();
      const feels = rows
        .map((r) => r.feel_rating)
        .filter((f): f is number => f != null);
      const avgFeelByPhase: Partial<Record<Phase, number>> = {};
      for (const phase of PHASES) {
        const phaseFeels = rows
          .filter((r) => r.week_phase === phase)
          .map((r) => r.feel_rating)
          .filter((f): f is number => f != null);
        if (phaseFeels.length) {
          avgFeelByPhase[phase] =
            phaseFeels.reduce((a, b) => a + b, 0) / phaseFeels.length;
        }
      }
      return {
        cycle,
        start: dates[0],
        end: dates[dates.length - 1],
        workouts: rows.length,
        avgFeel: feels.length
          ? feels.reduce((a, b) => a + b, 0) / feels.length
          : null,
        avgFeelByPhase,
      };
    });
}
