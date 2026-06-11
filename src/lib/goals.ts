import type { Goal, Phase } from "@/lib/types";
import { formatKg } from "@/lib/format";

export interface GoalContext {
  latestBodyWeight: number | null;
  /** max weight ever logged, per exercise id */
  prByExercise: Map<string, number>;
  /** completed workout dates (ISO strings) */
  workoutDates: string[];
}

export interface GoalProgress {
  progress: number; // 0..1
  current: string; // mono display of where she is now
  target: string;
  hit: boolean;
}

const CONSISTENCY_WINDOW_WEEKS = 4;

export function computeGoalProgress(goal: Goal, ctx: GoalContext): GoalProgress {
  if (goal.type === "body_weight") {
    const current = ctx.latestBodyWeight;
    const baseline = goal.baseline_value ?? current ?? goal.target_value;
    const target = goal.target_value;
    if (current == null) {
      return { progress: 0, current: "—", target: `${formatKg(target)} kg`, hit: false };
    }
    const total = Math.abs(baseline - target);
    const travelled = Math.abs(baseline - current);
    const rightDirection =
      baseline === target || (baseline > target ? current <= baseline : current >= baseline);
    const hit = baseline > target ? current <= target : current >= target;
    return {
      progress: hit ? 1 : total === 0 ? 0 : rightDirection ? Math.min(1, travelled / total) : 0,
      current: `${formatKg(current)} kg`,
      target: `${formatKg(target)} kg`,
      hit,
    };
  }

  if (goal.type === "exercise_pr") {
    const best = goal.exercise_id ? ctx.prByExercise.get(goal.exercise_id) ?? 0 : 0;
    return {
      progress: Math.min(1, best / goal.target_value),
      current: `${formatKg(best)} kg`,
      target: `${formatKg(goal.target_value)} kg`,
      hit: best >= goal.target_value,
    };
  }

  // consistency: target_value workouts per week, over the last 4 weeks
  const perWeek = goal.target_value;
  const now = Date.now();
  let weeksHit = 0;
  for (let w = 0; w < CONSISTENCY_WINDOW_WEEKS; w++) {
    const end = now - w * 7 * 86_400_000;
    const start = end - 7 * 86_400_000;
    const count = ctx.workoutDates.filter((d) => {
      const t = new Date(d).getTime();
      return t > start && t <= end;
    }).length;
    if (count >= perWeek) weeksHit++;
  }
  return {
    progress: weeksHit / CONSISTENCY_WINDOW_WEEKS,
    current: `${weeksHit}/${CONSISTENCY_WINDOW_WEEKS} wk`,
    target: `${perWeek}×/wk`,
    hit: weeksHit >= CONSISTENCY_WINDOW_WEEKS,
  };
}

export function goalLabel(goal: Goal): string {
  switch (goal.type) {
    case "body_weight":
      return "Body weight";
    case "exercise_pr":
      return goal.exercise?.short_label ?? goal.exercise?.name ?? "PR";
    case "consistency":
      return "Consistency";
  }
}

export type { Phase };
