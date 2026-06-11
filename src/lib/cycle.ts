import type { MovementPattern, Phase, RepProfile } from "./types";

export const PHASES: Phase[] = ["light", "medium", "hard"];

/**
 * Rep targets are derived from phase + the exercise's rep profile, never
 * stored. 3 sets, always. Compounds wave 10–12 / 6–8 / 4–6; pump work
 * stays in the ranges where it actually works (a 4-rep lateral raise is
 * just trap-heaving); timed holds wave in seconds.
 */
export const REP_TARGETS: Record<RepProfile, Record<Phase, string>> = {
  strength: { light: "10–12", medium: "6–8", hard: "4–6" },
  pump: { light: "15–20", medium: "12–15", hard: "10–12" },
  timed: { light: "30 s", medium: "40 s", hard: "45 s" },
};

/** Prefill value for the reps field (top of the phase range). */
export const REP_DEFAULT: Record<RepProfile, Record<Phase, number>> = {
  strength: { light: 12, medium: 8, hard: 6 },
  pump: { light: 20, medium: 15, hard: 12 },
  timed: { light: 30, medium: 40, hard: 45 },
};

// Unilaterals (lunges, split squats, step-ups) are balance-limited: a true
// 4–6RM Bulgarian split squat is a coordination gamble, not a strength
// stimulus. They wave one notch higher than other compounds.
const LUNGE_TARGETS: Record<Phase, string> = {
  light: "10–12",
  medium: "8–10",
  hard: "6–8",
};
const LUNGE_DEFAULT: Record<Phase, number> = { light: 12, medium: 10, hard: 8 };

export function repTarget(
  profile: RepProfile,
  pattern: MovementPattern,
  phase: Phase
): string {
  if (profile === "strength" && pattern === "lunge") return LUNGE_TARGETS[phase];
  return REP_TARGETS[profile][phase];
}

export function repDefault(
  profile: RepProfile,
  pattern: MovementPattern,
  phase: Phase
): number {
  if (profile === "strength" && pattern === "lunge") return LUNGE_DEFAULT[phase];
  return REP_DEFAULT[profile][phase];
}

/** Rest timer defaults — hard weeks earn longer rest. */
export const REST_SECONDS: Record<Phase, number> = {
  light: 90,
  medium: 90,
  hard: 120,
};

export const SETS_PER_EXERCISE = 3;

/** 3 of 5 sessions completes a week (checkbox). All 5 earns a star. */
export const WEEK_MIN_SESSIONS = 3;

export interface CycleLogRow {
  program_day_id: string;
  week_phase: Phase;
  cycle_number: number;
  completed_at: string;
  feel_rating: number | null;
}

export interface WeekClosure {
  cycle_number: number;
  week_phase: Phase;
}

export interface CycleState {
  cycle: number;
  phase: Phase;
  weekIndex: number; // 1..3
  doneDayIds: Set<string>; // days completed in the current cycle + phase
  nextDayId: string | null;
  /** ≥3 sessions done — she may close the week and move on. */
  weekClosable: boolean;
  /** True right after week 3 completes — the "cycle complete" moment. */
  cycleJustCompleted: boolean;
}

/**
 * The whole phase engine. State is derived from workout_logs, never stored:
 * the current cycle is the highest cycle logged (or the program's manual
 * reset floor), and the current week is the first phase that's unfinished.
 * A week is finished when all days are logged OR it was explicitly closed
 * (possible from 3/5 sessions). When the hard week finishes, the next
 * cycle starts at light automatically.
 */
export function deriveCycleState(
  logs: CycleLogRow[],
  orderedDayIds: string[],
  cycleFloor = 1,
  closures: WeekClosure[] = []
): CycleState {
  const maxLogged = logs.length
    ? Math.max(...logs.map((l) => l.cycle_number))
    : 0;
  const cycle = Math.max(maxLogged, cycleFloor, 1);
  const closed = new Set(
    closures.map((c) => `${c.cycle_number}:${c.week_phase}`)
  );

  for (let i = 0; i < PHASES.length; i++) {
    const phase = PHASES[i];
    const done = new Set(
      logs
        .filter((l) => l.cycle_number === cycle && l.week_phase === phase)
        .map((l) => l.program_day_id)
    );
    const finished =
      done.size >= orderedDayIds.length || closed.has(`${cycle}:${phase}`);
    if (!finished) {
      // Suggest the least-recently-trained day, not always Day 1 — if she
      // closes weeks at 3/5, the skipped days come first next week instead
      // of silently never happening.
      const lastDoneAt = new Map<string, string>();
      for (const l of logs) {
        const cur = lastDoneAt.get(l.program_day_id);
        if (!cur || l.completed_at > cur) {
          lastDoneAt.set(l.program_day_id, l.completed_at);
        }
      }
      const nextDayId =
        orderedDayIds
          .filter((id) => !done.has(id))
          .sort((a, b) => {
            const ta = lastDoneAt.get(a) ?? "";
            const tb = lastDoneAt.get(b) ?? "";
            if (ta !== tb) return ta < tb ? -1 : 1; // never/oldest first
            return orderedDayIds.indexOf(a) - orderedDayIds.indexOf(b);
          })[0] ?? null;
      return {
        cycle,
        phase,
        weekIndex: i + 1,
        doneDayIds: done,
        nextDayId,
        weekClosable: done.size >= WEEK_MIN_SESSIONS,
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
    weekClosable: false,
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
