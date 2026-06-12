import { unstable_cache } from "next/cache";
import { createClient as createBareClient } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";
import type {
  Exercise,
  Goal,
  Profile,
  Program,
  ProgramDay,
  ProgramExercise,
  ProgramWeek,
  Quote,
  WeekIntensity,
} from "@/lib/types";
import type { CycleLogRow } from "@/lib/cycle";
import { redirect } from "next/navigation";

export async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  return { supabase, user };
}

export async function getProfile(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string
): Promise<Profile | null> {
  const { data } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .maybeSingle();
  return data as Profile | null;
}

export interface ProgramWithDays extends Program {
  days: (ProgramDay & { exercises: (ProgramExercise & { exercise: Exercise })[] })[];
  /** Fixed-schedule programs only — empty for cycle programs. */
  week_plan: ProgramWeek[];
}

export async function getActiveProgram(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string
): Promise<ProgramWithDays | null> {
  // One round-trip: program + weeks + days + exercises nested.
  const { data: program } = await supabase
    .from("programs")
    .select(
      "*, program_weeks(*), program_days(*, program_exercises(*, exercise:exercises(*)))"
    )
    .eq("user_id", userId)
    .eq("active", true)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!program) return null;

  type NestedDay = ProgramDay & {
    program_exercises: (ProgramExercise & { exercise: Exercise })[];
  };
  const days = ((program.program_days ?? []) as NestedDay[])
    .slice()
    .sort(
      (a, b) =>
        (a.week_index ?? 0) - (b.week_index ?? 0) || a.day_index - b.day_index
    );
  const weekPlan = ((program.program_weeks ?? []) as ProgramWeek[])
    .slice()
    .sort((a, b) => a.week_index - b.week_index);

  return {
    ...(program as Program),
    week_plan: weekPlan,
    days: days.map((d) => ({
      ...d,
      exercises: [...(d.program_exercises ?? [])].sort((a, b) => a.sort - b.sort),
    })),
  };
}

export async function getCycleLogs(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
  dayIds: string[]
): Promise<CycleLogRow[]> {
  if (!dayIds.length) return [];
  const { data } = await supabase
    .from("workout_logs")
    .select("program_day_id, week_phase, cycle_number, completed_at, feel_rating")
    .eq("user_id", userId)
    .in("program_day_id", dayIds)
    .order("completed_at");
  return (data ?? []) as CycleLogRow[];
}

// Quotes are global and tiny — cache them in the server for a day instead
// of re-fetching on every dashboard render.
const getCachedQuotes = unstable_cache(
  async (): Promise<Quote[]> => {
    const supabase = createBareClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://placeholder.supabase.co",
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "placeholder-anon-key",
      { auth: { persistSession: false } }
    );
    const { data } = await supabase.from("quotes").select("*");
    return (data ?? []) as Quote[];
  },
  ["quotes"],
  { revalidate: 86_400 }
);

export async function getQuoteOfTheDay(): Promise<Quote | null> {
  try {
    const quotes = await getCachedQuotes();
    if (!quotes.length) return null;
    const dayOfYear = Math.floor(
      (Date.now() - new Date(new Date().getFullYear(), 0, 0).getTime()) /
        86_400_000
    );
    // Stable per-day rotation; sort for a consistent order.
    quotes.sort((a, b) => a.id.localeCompare(b.id));
    return quotes[dayOfYear % quotes.length];
  } catch {
    return null;
  }
}

export async function getWeekClosures(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string
): Promise<{ cycle_number: number; week_phase: WeekIntensity }[]> {
  const { data } = await supabase
    .from("week_closures")
    .select("cycle_number, week_phase")
    .eq("user_id", userId);
  return (data ?? []) as { cycle_number: number; week_phase: WeekIntensity }[];
}

export async function getGoals(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string
): Promise<Goal[]> {
  const { data } = await supabase
    .from("goals")
    .select("*, exercise:exercises(*)")
    .eq("user_id", userId)
    .order("created_at");
  return (data ?? []) as Goal[];
}

/** Per-exercise set history with the phase/cycle it was logged under. */
export interface SetHistoryRow {
  exercise_id: string;
  weight_kg: number | null;
  reps: number | null;
  sets: number | null;
  workout_log: {
    week_phase: string;
    cycle_number: number;
    completed_at: string;
  };
}

export async function getSetHistory(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
  exerciseIds: string[]
): Promise<SetHistoryRow[]> {
  if (!exerciseIds.length) return [];
  const { data } = await supabase
    .from("set_logs")
    .select(
      "exercise_id, weight_kg, reps, sets, workout_log:workout_logs!inner(week_phase, cycle_number, completed_at, user_id)"
    )
    .eq("workout_log.user_id", userId)
    .in("exercise_id", exerciseIds);
  return (data ?? []) as unknown as SetHistoryRow[];
}
