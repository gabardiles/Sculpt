import { notFound, redirect } from "next/navigation";
import {
  requireUser,
  getActiveProgram,
  getCycleLogs,
  getSetHistory,
} from "@/lib/data";
import { deriveCycleState } from "@/lib/cycle";
import { WorkoutClient, type WorkoutExercise } from "@/components/workout/WorkoutClient";

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
  const [logs, history] = await Promise.all([
    getCycleLogs(supabase, user.id, dayIds),
    getSetHistory(supabase, user.id, exerciseIds),
  ]);
  const state = deriveCycleState(logs, dayIds, program.cycle_floor);

  // "LAST: 40 kg" — most recent weight in the SAME phase (her hard-week
  // weight shouldn't show during light week). Trend arrow compares against
  // the previous cycle, same phase.
  const exercises: WorkoutExercise[] = day.exercises.map((pe) => {
    const rows = history
      .filter(
        (h) => h.exercise_id === pe.exercise_id && h.workout_log.week_phase === state.phase
      )
      .sort((a, b) =>
        b.workout_log.completed_at.localeCompare(a.workout_log.completed_at)
      );
    const last = rows[0] ?? null;
    const prevCycleRow =
      rows.find((r) => r.workout_log.cycle_number < (last?.workout_log.cycle_number ?? state.cycle)) ??
      null;
    return {
      programExerciseId: pe.id,
      exerciseId: pe.exercise_id,
      name: pe.exercise.name,
      shortLabel: pe.exercise.short_label,
      muscleGroup: pe.exercise.muscle_group,
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
    />
  );
}
