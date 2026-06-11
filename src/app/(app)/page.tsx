import Link from "next/link";
import { redirect } from "next/navigation";
import { ChevronRight, Heart, TrendingUp } from "lucide-react";
import {
  requireUser,
  getProfile,
  getActiveProgram,
  getCycleLogs,
  getQuoteOfTheDay,
  getGoals,
  getWeekClosures,
} from "@/lib/data";
import { deriveCycleState, REP_TARGETS, SETS_PER_EXERCISE } from "@/lib/cycle";
import { formatDay, formatKg, greeting } from "@/lib/format";
import { computeGoalProgress, goalLabel } from "@/lib/goals";
import { Card } from "@/components/ui/Card";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { ProgressRing } from "@/components/ui/ProgressRing";
import { DayList } from "@/components/dashboard/DayList";
import { CloseWeekButton } from "@/components/dashboard/CloseWeekButton";
import {
  CycleReview,
  type CycleReviewData,
} from "@/components/dashboard/CycleReview";
import { dayImage } from "@/lib/editorial";
import type { Exercise as ExerciseRow } from "@/lib/types";
import { Sparkline } from "@/components/weight/Sparkline";
import type { FeedPost } from "@/lib/types";

export default async function DashboardPage() {
  const { supabase, user } = await requireUser();
  const [profile, program] = await Promise.all([
    getProfile(supabase, user.id),
    getActiveProgram(supabase, user.id),
  ]);

  if (!profile?.name || !program) redirect("/onboarding");

  const dayIds = program.days.map((d) => d.id);
  const [logs, quote, goals, closures, { data: setRows }, { data: friendRows }] =
    await Promise.all([
      getCycleLogs(supabase, user.id, dayIds),
      getQuoteOfTheDay(),
      getGoals(supabase, user.id),
      getWeekClosures(supabase, user.id),
      supabase
        .from("set_logs")
        .select(
          "exercise_id, weight_kg, reps, sets, workout_log:workout_logs!inner(id, user_id, completed_at, cycle_number)"
        )
        .eq("workout_log.user_id", user.id),
      supabase.from("friends").select("friend_id").eq("user_id", user.id),
    ]);

  const state = deriveCycleState(logs, dayIds, program.cycle_floor, closures);
  const nextDay = program.days.find((d) => d.id === state.nextDayId);

  // Completion date per day in the current week, for the day list.
  const doneAtByDay = new Map<string, string>();
  for (const l of logs) {
    if (l.cycle_number === state.cycle && l.week_phase === state.phase) {
      doneAtByDay.set(l.program_day_id, l.completed_at);
    }
  }

  // ------------------------------------------------ this week + volume graph
  type SetRow = {
    exercise_id: string;
    weight_kg: number | null;
    reps: number | null;
    sets: number | null;
    workout_log: { id: string; completed_at: string; cycle_number: number };
  };
  const sets = (setRows ?? []) as unknown as SetRow[];

  // Volume per session = Σ weight × reps × sets (one set_log per exercise).
  const volumeBySession = new Map<string, { at: string; volume: number }>();
  for (const s of sets) {
    const entry = volumeBySession.get(s.workout_log.id) ?? {
      at: s.workout_log.completed_at,
      volume: 0,
    };
    if (s.weight_kg != null && s.reps != null) {
      entry.volume +=
        Number(s.weight_kg) * s.reps * (s.sets ?? SETS_PER_EXERCISE);
    }
    volumeBySession.set(s.workout_log.id, entry);
  }
  const sessions = [...volumeBySession.values()].sort((a, b) =>
    a.at.localeCompare(b.at)
  );
  const volumeSpark = sessions.slice(-8).map((s) => s.volume);

  const weekAgo = Date.now() - 7 * 86_400_000;
  const thisWeekLogs = logs.filter(
    (l) => new Date(l.completed_at).getTime() > weekAgo
  );
  const weekVolume = sessions
    .filter((s) => new Date(s.at).getTime() > weekAgo)
    .reduce((a, s) => a + s.volume, 0);
  const weekFeels = thisWeekLogs
    .map((l) => l.feel_rating)
    .filter((f): f is number => f != null);
  const avgFeel = weekFeels.length
    ? weekFeels.reduce((a, b) => a + b, 0) / weekFeels.length
    : null;

  // -------------------------------------------- cycle review (between cycles)
  // When a cycle just finished, review how it FELT and suggest refreshing
  // 1–2 pump-tier accessories — never the compounds. Boredom is a real
  // programming variable; progression on the big lifts is sacred.
  let review: CycleReviewData | null = null;
  if (state.cycleJustCompleted && state.cycle > 1) {
    const prev = state.cycle - 1;
    const prevLogs = logs.filter((l) => l.cycle_number === prev);
    const prevFeels = prevLogs
      .map((l) => l.feel_rating)
      .filter((f): f is number => f != null);
    const avgPrevFeel = prevFeels.length
      ? prevFeels.reduce((a, b) => a + b, 0) / prevFeels.length
      : null;
    const hardFeels = prevLogs
      .filter((l) => l.week_phase === "hard")
      .map((l) => l.feel_rating)
      .filter((f): f is number => f != null);
    const hardAvg = hardFeels.length
      ? hardFeels.reduce((a, b) => a + b, 0) / hardFeels.length
      : null;

    // Per-day average feel — a day that consistently rates low gets its
    // accessories refreshed first.
    const feelByDay = new Map<string, number[]>();
    for (const l of prevLogs) {
      if (l.feel_rating != null) {
        const arr = feelByDay.get(l.program_day_id) ?? [];
        arr.push(l.feel_rating);
        feelByDay.set(l.program_day_id, arr);
      }
    }
    const avgFeelOfDay = (dayId: string) => {
      const arr = feelByDay.get(dayId) ?? [];
      return arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : null;
    };
    let lowDay: { name: string; avg: number } | null = null;
    for (const d of program.days) {
      const avg = avgFeelOfDay(d.id);
      if (avg != null && avg <= 2.5 && (!lowDay || avg < lowDay.avg)) {
        lowDay = { name: d.name, avg };
      }
    }

    // Stale = max weight didn't move between the last two cycles.
    const maxByExCycle = new Map<string, Map<number, number>>();
    for (const s of sets) {
      if (s.weight_kg == null) continue;
      const byCycle = maxByExCycle.get(s.exercise_id) ?? new Map();
      const cyc = s.workout_log.cycle_number;
      byCycle.set(cyc, Math.max(byCycle.get(cyc) ?? 0, Number(s.weight_kg)));
      maxByExCycle.set(s.exercise_id, byCycle);
    }

    const inProgram = new Set(
      program.days.flatMap((d) => d.exercises.map((pe) => pe.exercise_id))
    );
    const { data: lib } = await supabase
      .from("exercises")
      .select("*")
      .eq("is_global", true);
    const library = (lib ?? []) as ExerciseRow[];

    const candidates = program.days
      .flatMap((d) => d.exercises.map((pe) => ({ pe, day: d })))
      .filter((x) => x.pe.exercise.rep_profile === "pump")
      .map((x) => {
        const m = maxByExCycle.get(x.pe.exercise_id);
        const cur = m?.get(prev);
        const before = m?.get(prev - 1);
        const stale = cur != null && before != null && cur <= before;
        const dayFeel = avgFeelOfDay(x.day.id);
        return { ...x, stale, dayFeel };
      })
      .filter((x) => x.stale)
      .sort((a, b) => (a.dayFeel ?? 5) - (b.dayFeel ?? 5));

    const suggestions: CycleReviewData["suggestions"] = [];
    for (const c of candidates) {
      if (suggestions.length >= 2) break;
      const alt = library.find(
        (e) =>
          !inProgram.has(e.id) &&
          e.id !== c.pe.exercise_id &&
          e.movement_pattern === c.pe.exercise.movement_pattern &&
          e.muscle_group === c.pe.exercise.muscle_group &&
          e.rep_profile === "pump"
      );
      if (!alt) continue;
      suggestions.push({
        programExerciseId: c.pe.id,
        fromName: c.pe.exercise.name,
        toId: alt.id,
        toName: alt.name,
        toEquipment: alt.equipment,
        reason:
          c.dayFeel != null && c.dayFeel <= 2.5
            ? `Flat for two cycles, and ${c.day.name} has been feeling heavy.`
            : "Same muscle, fresh feel — the weight here hasn't moved in two cycles.",
      });
    }

    review = {
      prevCycle: prev,
      sessions: prevLogs.length,
      avgFeel: avgPrevFeel,
      hardAvg,
      lowDayName: lowDay?.name ?? null,
      suggestions,
    };
  }

  // ------------------------------------------------- friend's latest session
  const friendIds = ((friendRows ?? []) as { friend_id: string }[]).map(
    (r) => r.friend_id
  );
  let friendPost: (FeedPost & { authorName: string }) | null = null;
  if (friendIds.length) {
    const [{ data: post }, { data: people }] = await Promise.all([
      supabase
        .from("feed_posts")
        .select("*")
        .in("user_id", friendIds)
        .in("type", ["workout", "pb"])
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase.from("profiles").select("id, name").in("id", friendIds),
    ]);
    if (post) {
      const nameById = new Map(
        ((people ?? []) as { id: string; name: string | null }[]).map((p) => [
          p.id,
          p.name ?? "A friend",
        ])
      );
      friendPost = {
        ...(post as FeedPost),
        authorName: nameById.get((post as FeedPost).user_id) ?? "A friend",
      };
    }
  }

  // ------------------------------------------------------------------- goals
  const activeGoals = goals.filter((g) => !g.achieved).slice(0, 3);
  let goalRows: {
    id: string;
    label: string;
    progress: number;
    current: string;
    hit: boolean;
  }[] = [];
  if (activeGoals.length) {
    const { data: bw } = await supabase
      .from("body_weight")
      .select("weight_kg")
      .eq("user_id", user.id)
      .order("date", { ascending: false })
      .limit(1)
      .maybeSingle();
    const prByExercise = new Map<string, number>();
    for (const s of sets) {
      if (s.weight_kg == null) continue;
      const cur = prByExercise.get(s.exercise_id) ?? 0;
      if (Number(s.weight_kg) > cur) prByExercise.set(s.exercise_id, Number(s.weight_kg));
    }
    const ctx = {
      latestBodyWeight: bw?.weight_kg ?? null,
      prByExercise,
      workoutDates: logs.map((l) => l.completed_at),
    };
    goalRows = activeGoals.map((g) => {
      const p = computeGoalProgress(g, ctx);
      return {
        id: g.id,
        label: goalLabel(g),
        progress: p.progress,
        current: p.current,
        hit: p.hit,
      };
    });
  }

  return (
    <main className="animate-fade-in">
      {/* header */}
      <header>
        <h1 className="text-2xl font-light tracking-wide">
          {greeting(profile.name)}
        </h1>
        <MonoNumber className="mt-1 block text-xs uppercase tracking-[0.14em] text-ink-soft">
          CYCLE {state.cycle} · WEEK {state.weekIndex} ·{" "}
          {state.phase.toUpperCase()}
        </MonoNumber>
      </header>

      {/* cycle complete — review, feel check, accessory refresh */}
      {review && (
        <section className="mt-6">
          <CycleReview review={review} newCycle={state.cycle} />
        </section>
      )}

      {/* what's next */}
      <section className="mt-6">
        {nextDay ? (
          <Link href={`/workout/${nextDay.id}`} className="block">
            <Card className="relative h-64 overflow-hidden bg-blush/25 p-0 active:scale-[0.99] transition-transform duration-150">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={dayImage(nextDay.day_index)}
                alt=""
                className="editorial-img absolute inset-0 h-full w-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-black/25 to-transparent" />
              <div className="absolute inset-x-0 bottom-0 p-6">
                <Eyebrow className="text-white/75">
                  NEXT UP · DAY {nextDay.day_index}
                </Eyebrow>
                <div className="mt-1 flex items-center justify-between gap-3">
                  <h2 className="text-4xl font-light leading-tight tracking-wide text-white">
                    {nextDay.name}
                  </h2>
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-blush text-on-accent">
                    <ChevronRight size={20} strokeWidth={2} />
                  </span>
                </div>
                <MonoNumber className="mt-2 block text-xs text-white/80">
                  {nextDay.exercises.length} exercises ·{" "}
                  {REP_TARGETS.strength[state.phase]} reps · 3 sets
                </MonoNumber>
              </div>
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

      {/* the week — thin rows with names, tappable in any order */}
      <section className="mt-5">
        <DayList
          days={program.days.map((d) => ({
            id: d.id,
            index: d.day_index,
            name: d.name,
            done: state.doneDayIds.has(d.id),
            doneAt: doneAtByDay.get(d.id) ?? null,
            isNext: d.id === state.nextDayId,
          }))}
        />
        {state.weekClosable && (
          <CloseWeekButton
            cycle={state.cycle}
            phase={state.phase}
            doneCount={state.doneDayIds.size}
            skippedNames={program.days
              .filter((d) => !state.doneDayIds.has(d.id))
              .map((d) => d.name)}
          />
        )}
      </section>

      {/* this week's numbers */}
      {logs.length > 0 && (
        <section className="mt-6">
          <Eyebrow>THIS WEEK</Eyebrow>
          <Card className="mt-2 p-4">
            <div className="flex items-center justify-around text-center">
              <div>
                <MonoNumber className="block text-2xl font-light">
                  {thisWeekLogs.length}
                </MonoNumber>
                <span className="text-[11px] text-ink-soft">sessions</span>
              </div>
              <div>
                <MonoNumber className="block text-2xl font-light">
                  {weekVolume >= 1000
                    ? `${formatKg(weekVolume / 1000)}t`
                    : Math.round(weekVolume)}
                </MonoNumber>
                <span className="text-[11px] text-ink-soft">
                  volume{weekVolume < 1000 ? " kg" : ""}
                </span>
              </div>
              <div>
                <MonoNumber className="block text-2xl font-light">
                  {avgFeel != null ? avgFeel.toFixed(1) : "—"}
                </MonoNumber>
                <span className="text-[11px] text-ink-soft">avg feel</span>
              </div>
            </div>
            {volumeSpark.length >= 2 && (
              <div className="mt-3 flex flex-col items-center">
                <Sparkline values={volumeSpark} width={260} height={36} />
                <MonoNumber className="mt-1 text-[11px] uppercase tracking-wider text-ink-soft/80">
                  volume · last {volumeSpark.length} sessions
                </MonoNumber>
              </div>
            )}
          </Card>
        </section>
      )}

      {/* friend's latest */}
      {friendPost && (
        <section className="mt-6">
          <Eyebrow>FRIENDS</Eyebrow>
          <Link href="/friends" className="block">
            <Card className="mt-2 flex items-center gap-3 px-5 py-4 active:scale-[0.99] transition-transform">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-blush/30">
                {friendPost.type === "pb" ? (
                  <TrendingUp size={17} strokeWidth={1.6} className="text-blush-deep" />
                ) : (
                  <Heart size={17} strokeWidth={1.6} className="text-blush-deep" />
                )}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm">
                  <span className="font-medium">{friendPost.authorName}</span>{" "}
                  <span className="font-light text-ink-soft">
                    {friendPost.body}
                  </span>
                </span>
                <MonoNumber className="text-[11px] uppercase tracking-wider text-ink-soft">
                  {formatDay(friendPost.created_at)}
                  {typeof friendPost.metadata?.phase === "string" && (
                    <> · {friendPost.metadata.phase as string}</>
                  )}
                </MonoNumber>
              </span>
              <ChevronRight size={16} strokeWidth={1.5} className="shrink-0 text-ink-soft" />
            </Card>
          </Link>
        </section>
      )}

      {/* goals */}
      {goalRows.length > 0 && (
        <section className="mt-6">
          <Eyebrow>GOALS</Eyebrow>
          <Card className="mt-2 p-4">
            <div className="flex items-center justify-around">
              {goalRows.map((g) => (
                <Link key={g.id} href="/goals" className="flex flex-col items-center gap-1.5">
                  <ProgressRing progress={g.progress} done={g.hit}>
                    <MonoNumber className="text-[11px] text-ink-soft">
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
            <p className="mt-1 text-center text-xs text-ink-soft/80">
              — {quote.author}
            </p>
          )}
        </section>
      )}
    </main>
  );
}
