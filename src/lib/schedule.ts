import type { Phase, SessionType, WeekIntensity } from "./types";
import { WEEK_MIN_SESSIONS, type CycleLogRow, type WeekClosure } from "./cycle";

/**
 * Fixed-schedule engine (Hybrid Athlete): 20 distinct prescribed weeks
 * instead of a repeating 3-week cycle. Same philosophy as the cycle engine —
 * state is derived from workout_logs, never stored. Days are unique across
 * the program, so "done" simply means a log exists for that day. Logs store
 * week_index in cycle_number and the week's intensity in week_phase.
 */

/** How the coach's intensity reads on screen — 'hard' is his HEAVY week. */
export const INTENSITY_LABEL: Record<WeekIntensity, string> = {
  light: "LIGHT",
  medium: "MEDIUM",
  hard: "HEAVY",
  test: "TEST",
};

export const SESSION_LABEL: Record<SessionType, string> = {
  strength: "Strength",
  crossfit: "CrossFit",
  conditioning: "Conditioning",
};

export const WEEKDAY_LABEL = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/** Rep targets and rest timers key off Phase — test days train like heavy. */
export function intensityToPhase(intensity: WeekIntensity): Phase {
  return intensity === "test" ? "hard" : intensity;
}

export interface ScheduleWeek {
  week_index: number;
  intensity: WeekIntensity;
  label: string | null;
  note: string | null;
  dayIds: string[]; // ordered by day_index
}

export interface ScheduleState {
  weekIndex: number; // 1..totalWeeks
  intensity: WeekIntensity;
  totalWeeks: number;
  doneDayIds: Set<string>; // across the whole program
  nextDayId: string | null;
  /** ≥3 sessions done this week — it may be closed and moved past. */
  weekClosable: boolean;
  /** Every week finished or closed — 20 weeks of work, done. */
  programComplete: boolean;
}

/**
 * Current week = the first week whose sessions aren't all logged and that
 * wasn't explicitly closed (closures store week_index in cycle_number).
 * Next session = the first unlogged day of that week, in schedule order.
 */
export function deriveScheduleState(
  weeks: ScheduleWeek[],
  logs: CycleLogRow[],
  closures: WeekClosure[] = []
): ScheduleState {
  const done = new Set(logs.map((l) => l.program_day_id));
  const closed = new Set(closures.map((c) => c.cycle_number));

  for (const week of weeks) {
    const doneInWeek = week.dayIds.filter((id) => done.has(id));
    const finished =
      doneInWeek.length >= week.dayIds.length ||
      closed.has(week.week_index) ||
      week.dayIds.length === 0;
    if (!finished) {
      return {
        weekIndex: week.week_index,
        intensity: week.intensity,
        totalWeeks: weeks.length,
        doneDayIds: done,
        nextDayId: week.dayIds.find((id) => !done.has(id)) ?? null,
        weekClosable:
          doneInWeek.length >= Math.min(WEEK_MIN_SESSIONS, week.dayIds.length),
        programComplete: false,
      };
    }
  }

  const last = weeks[weeks.length - 1];
  return {
    weekIndex: last?.week_index ?? 1,
    intensity: last?.intensity ?? "light",
    totalWeeks: weeks.length,
    doneDayIds: done,
    nextDayId: null,
    weekClosable: false,
    programComplete: weeks.length > 0,
  };
}
