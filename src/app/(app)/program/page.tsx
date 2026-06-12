import { redirect } from "next/navigation";
import {
  requireUser,
  getActiveProgram,
  getCycleLogs,
  getWeekClosures,
} from "@/lib/data";
import { deriveCycleState, summarizeCycles, PHASES } from "@/lib/cycle";
import { ProgramClient } from "@/components/program/ProgramClient";
import type { Exercise, Phase } from "@/lib/types";

export default async function ProgramPage() {
  const { supabase, user } = await requireUser();
  const program = await getActiveProgram(supabase, user.id);
  if (!program) redirect("/onboarding");

  const dayIds = program.days.map((d) => d.id);
  const [logs, closures] = await Promise.all([
    getCycleLogs(supabase, user.id, dayIds),
    getWeekClosures(supabase, user.id),
  ]);
  const state = deriveCycleState(logs, dayIds, program.cycle_floor, closures);

  // Week status for the current cycle: star = all 5, check = closed at 3+.
  const weekStatus: Record<Phase, "star" | "check" | "open"> = {
    light: "open",
    medium: "open",
    hard: "open",
  };
  for (const phase of PHASES) {
    const count = logs.filter(
      (l) => l.cycle_number === state.cycle && l.week_phase === phase
    ).length;
    const closed = closures.some(
      (c) => c.cycle_number === state.cycle && c.week_phase === phase
    );
    weekStatus[phase] =
      count >= dayIds.length ? "star" : closed ? "check" : "open";
  }
  const summaries = summarizeCycles(logs).filter((s) => s.cycle !== state.cycle);

  // Completion date per (phase, day) in the current cycle — for sage stamps.
  const doneStamps: Record<Phase, Record<string, string>> = {
    light: {},
    medium: {},
    hard: {},
  };
  for (const l of logs) {
    if (l.cycle_number === state.cycle) {
      doneStamps[l.week_phase][l.program_day_id] = l.completed_at;
    }
  }

  // Feel insight: if her last completed cycle's hard week averaged ≤ 2,
  // gently suggest repeating a medium week. Smart, not preachy.
  const lastCompleted = summaries[0];
  const hardFeelsLow =
    lastCompleted?.avgFeelByPhase.hard != null &&
    lastCompleted.avgFeelByPhase.hard <= 2;

  // Full global library for the swap sheet (filtered client-side by
  // movement_pattern + muscle_group — the guardrail).
  const { data: library } = await supabase
    .from("exercises")
    .select("*")
    .or(`is_global.eq.true,created_by.eq.${user.id}`)
    .order("name");

  return (
    <ProgramClient
      program={{ id: program.id, name: program.name }}
      days={program.days.map((d) => ({
        id: d.id,
        index: d.day_index,
        name: d.name,
        exercises: d.exercises.map((pe) => ({
          programExerciseId: pe.id,
          sort: pe.sort,
          exercise: pe.exercise,
        })),
      }))}
      phases={PHASES}
      cycle={state.cycle}
      currentPhase={state.phase}
      doneStamps={doneStamps}
      summaries={summaries}
      library={(library ?? []) as Exercise[]}
      hardFeelsLow={hardFeelsLow}
      weekStatus={weekStatus}
    />
  );
}
