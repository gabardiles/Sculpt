import { notFound, redirect } from "next/navigation";
import {
  requireUser,
  getActiveProgram,
  getCycleLogs,
  getSetHistory,
  getWeekClosures,
} from "@/lib/data";
import { deriveCycleState } from "@/lib/cycle";
import {
  DAY_RATIONALE,
  SHARE_PROMPTS,
  SHARE_PROMPT_FALLBACK,
} from "@/lib/programCopy";
import { WorkoutClient, type WorkoutExercise } from "@/components/workout/WorkoutClient";
import type { Phase } from "@/lib/types";

export default async function WorkoutPage({
  params,
}: {
  params: Promise<{ dayId: string }>;
}) {
  const { dayId } = await params;
  const { supabase, user } = await requireUser();
  const program = await getActiveProgram(supabase, user.id);
  if (!program) redirect("/onboarding");

  const day = program.days.find((d) => d.id === dayId);
  if (!day) notFound();

  const dayIds = program.days.map((d) => d.id);
  const exerciseIds = day.exercises.map((pe) => pe.exercise_id);
  const [logs, history, closures] = await Promise.all([
    getCycleLogs(supabase, user.id, dayIds),
    getSetHistory(supabase, user.id, exerciseIds),
    getWeekClosures(supabase, user.id),
  ]);
  const state = deriveCycleState(logs, dayIds, program.cycle_floor, closures);

  // "LAST: 40 kg" — most recent weight in the SAME phase (her hard-week
  // weight shouldn't show during light week). First time in a new phase
  // there's no same-phase history yet, so fall back to the most recent
  // session from ANY week — labeled, so she knows it came from a
  // different intensity. Trend arrow compares previous cycle, same phase.
  const exercises: WorkoutExercise[] = day.exercises.map((pe) => {
    const allRows = history
      .filter((h) => h.exercise_id === pe.exercise_id)
      .sort((a, b) =>
        b.workout_log.completed_at.localeCompare(a.workout_log.completed_at)
      );
    const rows = allRows.filter(
      (h) => h.workout_log.week_phase === state.phase
    );
    const last = rows[0] ?? allRows[0] ?? null;
    const lastIsOtherPhase =
      last != null && last.workout_log.week_phase !== state.phase;
    const prevCycleRow =
      rows.find(
        (r) =>
          r.workout_log.cycle_number <
          (rows[0]?.workout_log.cycle_number ?? state.cycle)
      ) ?? null;
    return {
      programExerciseId: pe.id,
      exerciseId: pe.exercise_id,
      name: pe.exercise.name,
      shortLabel: pe.exercise.short_label,
      muscleGroup: pe.exercise.muscle_group,
      movementPattern: pe.exercise.movement_pattern,
      equipment: pe.exercise.equipment,
      unit: pe.exercise.unit,
      repProfile: pe.exercise.rep_profile,
      cue: pe.exercise.cue,
      instructionUrl: pe.exercise.instruction_url,
      imageUrl: pe.exercise.image_url,
      sets: pe.sets,
      lastWeight: last?.weight_kg ?? null,
      lastReps: last?.reps ?? null,
      lastSets: last?.sets ?? null,
      lastPhase: lastIsOtherPhase
        ? (last.workout_log.week_phase as Phase)
        : null,
      prevCycleWeight: prevCycleRow?.weight_kg ?? null,
    };
  });

  const alreadyDone = state.doneDayIds.has(day.id);

  return (
    <WorkoutClient
      day={{ id: day.id, name: day.name, index: day.day_index }}
      phase={state.phase}
      cycle={state.cycle}
      weekIndex={state.weekIndex}
      exercises={exercises}
      alreadyDone={alreadyDone}
      rationale={DAY_RATIONALE[day.name] ?? null}
      sharePrompt={SHARE_PROMPTS[day.name] ?? SHARE_PROMPT_FALLBACK}
      userId={user.id}
    />
  );
}
