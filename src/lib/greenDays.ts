// Green Days gamification — the web twin of ios/Sculpt/Core/Engine/GreenDays.swift.
// Both platforms must agree on every verdict, point and streak.
//
//   Green = trained OR hit the step goal that day.
//   Gold  = trained AND hit the step goal (a bonus on top).

export type DayState = "none" | "green" | "gold";

export interface ActivityDay {
  user_id?: string;
  date: string; // yyyy-MM-dd
  steps: number;
  step_goal: number;
  workout_done: boolean;
}

export const WORKOUT_POINTS = 100;
export const STEP_POINTS = 50;
export const GOLD_BONUS = 25;
export const DEFAULT_STEP_GOAL = 10_000;

export const TIERS = [
  { name: "Spark", minPoints: 0 },
  { name: "Ember", minPoints: 300 },
  { name: "Kindle", minPoints: 800 },
  { name: "Flame", minPoints: 1_600 },
  { name: "Blaze", minPoints: 3_200 },
  { name: "Wildfire", minPoints: 6_000 },
] as const;

export const MILESTONES = [3, 7, 14, 30, 60, 100];

export function stepGoalHit(d: ActivityDay): boolean {
  return d.step_goal > 0 && d.steps >= d.step_goal;
}

export function dayState(d: ActivityDay): DayState {
  const hit = stepGoalHit(d);
  if (d.workout_done && hit) return "gold";
  if (d.workout_done || hit) return "green";
  return "none";
}

export function dayPoints(d: ActivityDay): number {
  let p = 0;
  if (d.workout_done) p += WORKOUT_POINTS;
  if (stepGoalHit(d)) p += STEP_POINTS;
  if (dayState(d) === "gold") p += GOLD_BONUS;
  return p;
}

export interface GreenSummary {
  currentStreak: number;
  longestStreak: number;
  totalPoints: number;
  greenDays: number;
  goldDays: number;
  levelIndex: number;
  levelName: string;
  pointsIntoLevel: number;
  pointsForLevelSpan: number;
  nextLevelName: string | null;
  levelProgress: number;
}

export function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

function addDays(iso: string, n: number): string {
  const d = new Date(iso + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function levelForPoints(points: number): number {
  let idx = 0;
  TIERS.forEach((t, i) => {
    if (points >= t.minPoints) idx = i;
  });
  return idx;
}

export function currentStreak(greenDates: Set<string>, today = todayISO()): number {
  let cursor = greenDates.has(today) ? today : addDays(today, -1);
  let streak = 0;
  while (greenDates.has(cursor)) {
    streak += 1;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

export function longestStreak(greenDates: Set<string>): number {
  const sorted = [...greenDates].sort();
  if (!sorted.length) return 0;
  let best = 1;
  let run = 1;
  for (let i = 1; i < sorted.length; i++) {
    run = addDays(sorted[i - 1], 1) === sorted[i] ? run + 1 : 1;
    best = Math.max(best, run);
  }
  return best;
}

export function summarize(days: ActivityDay[], today = todayISO()): GreenSummary {
  const green = new Set(days.filter((d) => dayState(d) !== "none").map((d) => d.date));
  const totalPoints = days.reduce((s, d) => s + dayPoints(d), 0);
  const idx = levelForPoints(totalPoints);
  const span = idx + 1 < TIERS.length ? TIERS[idx + 1].minPoints - TIERS[idx].minPoints : 0;
  const into = totalPoints - TIERS[idx].minPoints;
  return {
    currentStreak: currentStreak(green, today),
    longestStreak: longestStreak(green),
    totalPoints,
    greenDays: days.filter((d) => dayState(d) === "green").length,
    goldDays: days.filter((d) => dayState(d) === "gold").length,
    levelIndex: idx,
    levelName: TIERS[idx].name,
    pointsIntoLevel: into,
    pointsForLevelSpan: span,
    nextLevelName: idx + 1 < TIERS.length ? TIERS[idx + 1].name : null,
    levelProgress: span <= 0 ? 1 : Math.min(1, into / span),
  };
}
