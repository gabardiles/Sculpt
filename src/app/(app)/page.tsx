import Link from "next/link";
import { redirect } from "next/navigation";
import { ChevronRight, LogOut, UserPlus } from "lucide-react";
import {
  requireUser,
  getProfile,
  getActiveProgram,
  getCycleLogs,
  getQuoteOfTheDay,
  getGoals,
} from "@/lib/data";
import { deriveCycleState, REP_TARGETS } from "@/lib/cycle";
import { greeting } from "@/lib/format";
import { signOut } from "@/lib/actions";
import { computeGoalProgress, goalLabel } from "@/lib/goals";
import { Card } from "@/components/ui/Card";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { ProgressRing } from "@/components/ui/ProgressRing";
import { WeekStrip } from "@/components/dashboard/WeekStrip";

export default async function DashboardPage() {
  const { supabase, user } = await requireUser();
  const profile = await getProfile(supabase, user.id);
  const program = await getActiveProgram(supabase, user.id);

  if (!profile?.name || !program) redirect("/onboarding");

  const dayIds = program.days.map((d) => d.id);
  const [logs, quote, goals] = await Promise.all([
    getCycleLogs(supabase, user.id, dayIds),
    getQuoteOfTheDay(supabase),
    getGoals(supabase, user.id),
  ]);

  const state = deriveCycleState(logs, dayIds, program.cycle_floor);
  const nextDay = program.days.find((d) => d.id === state.nextDayId);

  // Goal progress context (only fetched if she has active goals)
  const activeGoals = goals.filter((g) => !g.achieved).slice(0, 3);
  let goalRows: { id: string; label: string; progress: number; current: string; hit: boolean }[] = [];
  if (activeGoals.length) {
    const [{ data: bw }, { data: prs }] = await Promise.all([
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
    ]);
    const prByExercise = new Map<string, number>();
    for (const row of (prs ?? []) as { exercise_id: string; weight_kg: number }[]) {
      const cur = prByExercise.get(row.exercise_id) ?? 0;
      if (row.weight_kg > cur) prByExercise.set(row.exercise_id, row.weight_kg);
    }
    const ctx = {
      latestBodyWeight: bw?.weight_kg ?? null,
      prByExercise,
      workoutDates: logs.map((l) => l.completed_at),
    };
    goalRows = activeGoals.map((g) => {
      const p = computeGoalProgress(g, ctx);
      return { id: g.id, label: goalLabel(g), progress: p.progress, current: p.current, hit: p.hit };
    });
  }

  return (
    <main className="animate-fade-up">
      {/* header */}
      <header className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-light tracking-wide">
            {greeting(profile.name)}
          </h1>
          <MonoNumber className="mt-1 block text-[11px] uppercase tracking-[0.14em] text-ink-soft">
            CYCLE {state.cycle} · WEEK {state.weekIndex} ·{" "}
            {state.phase.toUpperCase()}
          </MonoNumber>
        </div>
        <div className="flex items-center gap-1">
          {profile.is_admin && (
            <Link
              href="/admin"
              aria-label="Invite"
              className="flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
            >
              <UserPlus size={18} strokeWidth={1.5} />
            </Link>
          )}
          <form action={signOut}>
            <button
              aria-label="Sign out"
              className="flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
            >
              <LogOut size={18} strokeWidth={1.5} />
            </button>
          </form>
        </div>
      </header>

      {/* what's next */}
      <section className="mt-6">
        {nextDay ? (
          <Link href={`/workout/${nextDay.id}`} className="block">
            <Card className="hero-gradient p-6 active:scale-[0.99] transition-transform duration-150">
              <Eyebrow>NEXT UP · DAY {nextDay.day_index}</Eyebrow>
              <div className="mt-2 flex items-center justify-between">
                <h2 className="text-2xl font-light tracking-wide">
                  {nextDay.name}
                </h2>
                <ChevronRight size={22} strokeWidth={1.5} className="text-ink-soft" />
              </div>
              <MonoNumber className="mt-3 block text-xs text-ink-soft">
                {nextDay.exercises.length} exercises · {REP_TARGETS[state.phase]}{" "}
                reps · 3 sets
              </MonoNumber>
            </Card>
          </Link>
        ) : (
          <Card className="p-6 text-center">
            <p className="font-light text-lg">Week complete</p>
            <p className="mt-1 text-sm text-ink-soft">
              Everything done. Rest is part of the work.
            </p>
          </Card>
        )}
      </section>

      {/* week strip */}
      <section className="mt-5">
        <WeekStrip
          days={program.days.map((d) => ({
            id: d.id,
            index: d.day_index,
            done: state.doneDayIds.has(d.id),
            isNext: d.id === state.nextDayId,
          }))}
        />
      </section>

      {/* goals */}
      {goalRows.length > 0 && (
        <section className="mt-6">
          <Eyebrow>GOALS</Eyebrow>
          <Card className="mt-2 p-4">
            <div className="flex items-center justify-around">
              {goalRows.map((g) => (
                <Link key={g.id} href="/goals" className="flex flex-col items-center gap-1.5">
                  <ProgressRing progress={g.progress} done={g.hit}>
                    <MonoNumber className="text-[10px] text-ink-soft">
                      {Math.round(g.progress * 100)}%
                    </MonoNumber>
                  </ProgressRing>
                  <span className="text-[11px] text-ink-soft">{g.label}</span>
                </Link>
              ))}
            </div>
          </Card>
        </section>
      )}

      {/* quote of the day */}
      {quote && (
        <section className="mt-8 px-2">
          <p className="text-center text-sm font-light leading-relaxed text-ink-soft">
            “{quote.text}”
          </p>
          {quote.author && (
            <p className="mt-1 text-center text-xs text-ink-soft/60">
              — {quote.author}
            </p>
          )}
        </section>
      )}
    </main>
  );
}
