import {
  requireUser,
  getGoals,
  getActiveProgram,
  getCycleLogs,
} from "@/lib/data";
import { computeGoalProgress, goalLabel, type GoalContext } from "@/lib/goals";
import { Eyebrow } from "@/components/ui/MonoNumber";
import { GoalsClient, type GoalRow } from "@/components/goals/GoalsClient";
import type { Exercise } from "@/lib/types";

export default async function GoalsPage() {
  const { supabase, user } = await requireUser();

  const [goals, program] = await Promise.all([
    getGoals(supabase, user.id),
    getActiveProgram(supabase, user.id),
  ]);
  const dayIds = program?.days.map((d) => d.id) ?? [];
  const logs = program ? await getCycleLogs(supabase, user.id, dayIds) : [];

  const [{ data: bw }, { data: prs }, { data: library }] = await Promise.all([
    supabase
      .from("body_weight")
      .select("weight_kg")
      .eq("user_id", user.id)
      .order("date", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from("set_logs")
      .select("exercise_id, weight_kg, workout_log:workout_logs!inner(user_id)")
      .eq("workout_log.user_id", user.id)
      .not("weight_kg", "is", null),
    supabase.from("exercises").select("*").eq("is_global", true).order("name"),
  ]);

  const prByExercise = new Map<string, number>();
  for (const row of (prs ?? []) as { exercise_id: string; weight_kg: number }[]) {
    const cur = prByExercise.get(row.exercise_id) ?? 0;
    if (row.weight_kg > cur) prByExercise.set(row.exercise_id, row.weight_kg);
  }
  const ctx: GoalContext = {
    latestBodyWeight: bw?.weight_kg ?? null,
    prByExercise,
    workoutDates: logs.map((l) => l.completed_at),
  };

  // Auto-check goals against logs; persist newly-hit ones.
  const rows: GoalRow[] = [];
  for (const g of goals) {
    const p = computeGoalProgress(g, ctx);
    if (p.hit && !g.achieved) {
      await supabase
        .from("goals")
        .update({ achieved: true, achieved_at: new Date().toISOString() })
        .eq("id", g.id);
      g.achieved = true;
    }
    rows.push({
      id: g.id,
      type: g.type,
      label: goalLabel(g),
      progress: p.progress,
      current: p.current,
      target: p.target,
      achieved: g.achieved,
      deadline: g.deadline,
    });
  }

  return (
    <main className="animate-fade-up">
      <Eyebrow>GOALS</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">
        Three at a time
      </h1>
      <GoalsClient goals={rows} library={(library ?? []) as Exercise[]} />
    </main>
  );
}
