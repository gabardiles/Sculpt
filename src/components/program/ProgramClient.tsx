"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  Check,
  MoreHorizontal,
  Pencil,
  Plus,
  Repeat,
  Search,
  Trash2,
} from "lucide-react";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sheet } from "@/components/ui/Sheet";
import { addExercise, removeExercise, resetCycle, swapExercise } from "@/lib/actions";
import { REP_TARGETS, type CycleSummary } from "@/lib/cycle";
import type { Exercise, Phase } from "@/lib/types";
import { formatDay, formatRange } from "@/lib/format";
import { cn } from "@/lib/cn";

interface DayRow {
  id: string;
  index: number;
  name: string;
  exercises: { programExerciseId: string; sort: number; exercise: Exercise }[];
}

export function ProgramClient({
  program,
  days,
  phases,
  cycle,
  currentPhase,
  doneStamps,
  summaries,
  library,
  hardFeelsLow,
}: {
  program: { id: string; name: string };
  days: DayRow[];
  phases: Phase[];
  cycle: number;
  currentPhase: Phase;
  doneStamps: Record<Phase, Record<string, string>>;
  summaries: CycleSummary[];
  library: Exercise[];
  hardFeelsLow: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [swapFor, setSwapFor] = useState<{
    programExerciseId: string;
    exercise: Exercise;
  } | null>(null);
  const [addFor, setAddFor] = useState<DayRow | null>(null);
  const [search, setSearch] = useState("");
  const [busy, setBusy] = useState(false);

  // The guardrail: only same movement pattern + same primary muscle group.
  // Same training role (rep_profile) comes first — a heavy compound and a
  // pump finisher are not real substitutes, even when the muscle matches.
  const swapOptions = useMemo(() => {
    if (!swapFor) return { sameTier: [], otherTier: [] };
    const compatible = library.filter(
      (e) =>
        e.id !== swapFor.exercise.id &&
        e.movement_pattern === swapFor.exercise.movement_pattern &&
        e.muscle_group === swapFor.exercise.muscle_group
    );
    return {
      sameTier: compatible.filter(
        (e) => e.rep_profile === swapFor.exercise.rep_profile
      ),
      otherTier: compatible.filter(
        (e) => e.rep_profile !== swapFor.exercise.rep_profile
      ),
    };
  }, [swapFor, library]);

  const addOptions = useMemo(() => {
    if (!addFor) return [];
    const q = search.trim().toLowerCase();
    const inDay = new Set(addFor.exercises.map((x) => x.exercise.id));
    return library
      .filter((e) => !inDay.has(e.id))
      .filter(
        (e) =>
          !q ||
          e.name.toLowerCase().includes(q) ||
          e.muscle_group.includes(q) ||
          e.movement_pattern.includes(q)
      )
      .slice(0, 30);
  }, [addFor, library, search]);

  async function doSwap(newId: string) {
    if (!swapFor || busy) return;
    setBusy(true);
    await swapExercise(swapFor.programExerciseId, newId);
    setSwapFor(null);
    setBusy(false);
  }

  async function doAdd(exerciseId: string) {
    if (!addFor || busy) return;
    setBusy(true);
    const nextSort = Math.max(0, ...addFor.exercises.map((x) => x.sort)) + 1;
    await addExercise(addFor.id, exerciseId, nextSort);
    setAddFor(null);
    setSearch("");
    setBusy(false);
  }

  async function doReset() {
    if (busy) return;
    setBusy(true);
    await resetCycle(program.id, cycle + 1);
    setMenuOpen(false);
    setBusy(false);
  }

  return (
    <main className="animate-fade-in">
      <header className="flex items-start justify-between">
        <div>
          <Eyebrow>PROGRAM</Eyebrow>
          <h1 className="mt-1 text-3xl font-light tracking-wide">
            {program.name}
          </h1>
          <MonoNumber className="mt-1 block text-[11px] uppercase tracking-[0.14em] text-ink-soft">
            CYCLE {cycle} · {currentPhase.toUpperCase()} WEEK
          </MonoNumber>
        </div>
        <div className="flex items-center">
          <button
            aria-label={editing ? "Done editing" : "Edit program"}
            onClick={() => setEditing(!editing)}
            className={cn(
              "flex h-12 w-12 items-center justify-center rounded-full transition-colors",
              editing ? "bg-blush text-ink" : "text-ink-soft active:bg-ink/5"
            )}
          >
            {editing ? <Check size={18} strokeWidth={1.8} /> : <Pencil size={17} strokeWidth={1.5} />}
          </button>
          <button
            aria-label="More"
            onClick={() => setMenuOpen(true)}
            className="flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
          >
            <MoreHorizontal size={20} strokeWidth={1.5} />
          </button>
        </div>
      </header>

      {hardFeelsLow && (
        <Card className="mt-4 border-blush/60 p-4">
          <p className="text-sm font-light leading-relaxed text-ink-soft">
            Last cycle&apos;s hard week felt rough. Repeating a medium week
            before going hard again is a strong move, not a step back.
          </p>
        </Card>
      )}

      {/* the 3-week cycle, stacked */}
      <div className="mt-6 flex flex-col gap-8">
        {phases.map((phase, wi) => {
          const stamps = doneStamps[phase];
          const isCurrent = phase === currentPhase;
          return (
            <section key={phase}>
              <div className="flex items-baseline justify-between">
                <h2 className="font-light tracking-wide">
                  <MonoNumber
                    className={cn(
                      "text-[11px] uppercase tracking-[0.14em]",
                      isCurrent ? "text-blush-deep" : "text-ink-soft"
                    )}
                  >
                    WEEK {wi + 1} · {phase.toUpperCase()}
                  </MonoNumber>
                </h2>
                <MonoNumber className="text-[11px] text-ink-soft">
                  {REP_TARGETS.strength[phase]} reps
                </MonoNumber>
              </div>

              <div className="mt-2 flex flex-col gap-3">
                {days.map((day) => {
                  const doneAt = stamps[day.id];
                  return (
                    <Card key={day.id} done={!!doneAt} className="overflow-hidden">
                      <Link
                        href={`/workout/${day.id}`}
                        className="flex items-center justify-between px-5 py-4 min-h-12"
                      >
                        <div>
                          <Eyebrow>DAY {day.index}</Eyebrow>
                          <p className="mt-0.5 font-normal">{day.name}</p>
                        </div>
                        {doneAt ? (
                          <MonoNumber className="text-xs text-sage-deep">
                            {formatDay(doneAt)}
                          </MonoNumber>
                        ) : (
                          <MonoNumber className="text-xs text-ink-soft">
                            {day.exercises.length} exercises
                          </MonoNumber>
                        )}
                      </Link>

                      {/* exercise rows only in the first (light) section to
                          avoid repeating the same list three times */}
                      {(editing || wi === 0) && (
                        <ul className="border-t border-white/50 px-5 py-2">
                          {day.exercises.map((row) => (
                            <li
                              key={row.programExerciseId}
                              className="flex items-center justify-between gap-2 py-1.5"
                            >
                              <span className="flex-1 truncate text-sm font-light">
                                {row.exercise.name}
                              </span>
                              <MonoNumber className="text-[10px] uppercase text-ink-soft/70">
                                {row.exercise.equipment}
                              </MonoNumber>
                              {editing && (
                                <span className="flex items-center">
                                  <button
                                    aria-label={`Swap ${row.exercise.name}`}
                                    onClick={() =>
                                      setSwapFor({
                                        programExerciseId: row.programExerciseId,
                                        exercise: row.exercise,
                                      })
                                    }
                                    className="flex h-10 w-10 items-center justify-center rounded-full text-blush-deep active:bg-blush/20"
                                  >
                                    <Repeat size={16} strokeWidth={1.5} />
                                  </button>
                                  <button
                                    aria-label={`Remove ${row.exercise.name}`}
                                    onClick={() => removeExercise(row.programExerciseId)}
                                    className="flex h-10 w-10 items-center justify-center rounded-full text-ink-soft/80 active:bg-ink/5"
                                  >
                                    <Trash2 size={15} strokeWidth={1.5} />
                                  </button>
                                </span>
                              )}
                            </li>
                          ))}
                          {editing && (
                            <li className="py-1.5">
                              <button
                                onClick={() => setAddFor(day)}
                                className="flex min-h-10 items-center gap-2 text-sm text-blush-deep"
                              >
                                <Plus size={16} strokeWidth={1.5} /> Add exercise
                              </button>
                            </li>
                          )}
                        </ul>
                      )}
                    </Card>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>

      {/* cycle history */}
      {summaries.length > 0 && (
        <section className="mt-10">
          <Eyebrow>HISTORY</Eyebrow>
          <ul className="mt-2 flex flex-col gap-1.5">
            {summaries.map((s) => (
              <li key={s.cycle}>
                <MonoNumber className="block text-xs text-ink-soft">
                  CYCLE {s.cycle} · {formatRange(s.start, s.end)} ·{" "}
                  {s.workouts} sessions
                  {s.avgFeel != null && <> · avg feel {s.avgFeel.toFixed(1)}</>}
                </MonoNumber>
              </li>
            ))}
          </ul>
        </section>
      )}

      {/* small menu — manual reset lives here, out of the way */}
      <Sheet open={menuOpen} onClose={() => setMenuOpen(false)} title="Program">
        <div className="flex flex-col gap-3 pb-2">
          <p className="text-sm font-light text-ink-soft">
            Resetting starts cycle {cycle + 1} at a light week. Logged history
            stays.
          </p>
          <PillButton variant="ghost" onClick={doReset} disabled={busy}>
            Reset cycle
          </PillButton>
        </div>
      </Sheet>

      {/* smart swap — only compatible alternatives */}
      <Sheet
        open={swapFor != null}
        onClose={() => setSwapFor(null)}
        title={`Swap ${swapFor?.exercise.name ?? ""}`}
      >
        <div className="pb-2">
          <MonoNumber className="text-[10px] uppercase tracking-wider text-ink-soft">
            {swapFor?.exercise.movement_pattern} · {swapFor?.exercise.muscle_group}
          </MonoNumber>
          {swapOptions.sameTier.length + swapOptions.otherTier.length === 0 ? (
            <p className="mt-4 text-sm font-light text-ink-soft">
              No equivalent alternatives in the library yet.
            </p>
          ) : (
            <>
              <ul className="mt-3 flex flex-col gap-2">
                {swapOptions.sameTier.map((e) => (
                  <li key={e.id}>
                    <button
                      onClick={() => doSwap(e.id)}
                      disabled={busy}
                      className="glass flex w-full items-center justify-between px-4 py-3 min-h-12 text-left active:scale-[0.99] transition-transform"
                    >
                      <span className="text-sm">{e.name}</span>
                      <MonoNumber className="text-[10px] uppercase text-ink-soft">
                        {e.equipment}
                      </MonoNumber>
                    </button>
                  </li>
                ))}
              </ul>
              {swapOptions.otherTier.length > 0 && (
                <>
                  <MonoNumber className="mt-4 block text-[10px] uppercase tracking-wider text-ink-soft/80">
                    Different intensity
                  </MonoNumber>
                  <ul className="mt-2 flex flex-col gap-2">
                    {swapOptions.otherTier.map((e) => (
                      <li key={e.id}>
                        <button
                          onClick={() => doSwap(e.id)}
                          disabled={busy}
                          className="glass flex w-full items-center justify-between px-4 py-3 min-h-12 text-left opacity-80 active:scale-[0.99] transition-transform"
                        >
                          <span className="text-sm">{e.name}</span>
                          <MonoNumber className="text-[10px] uppercase text-ink-soft">
                            {e.rep_profile} · {e.equipment}
                          </MonoNumber>
                        </button>
                      </li>
                    ))}
                  </ul>
                </>
              )}
            </>
          )}
        </div>
      </Sheet>

      {/* add exercise */}
      <Sheet
        open={addFor != null}
        onClose={() => {
          setAddFor(null);
          setSearch("");
        }}
        title={`Add to ${addFor?.name ?? ""}`}
      >
        <div className="pb-2">
          <div className="flex items-center gap-2 rounded-full border border-ink/10 bg-white/60 px-4">
            <Search size={16} strokeWidth={1.5} className="text-ink-soft" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search the library"
              className="h-12 flex-1 bg-transparent text-sm outline-none"
            />
          </div>
          <ul className="mt-3 flex flex-col gap-2">
            {addOptions.map((e) => (
              <li key={e.id}>
                <button
                  onClick={() => doAdd(e.id)}
                  disabled={busy}
                  className="glass flex w-full items-center justify-between px-4 py-3 min-h-12 text-left active:scale-[0.99] transition-transform"
                >
                  <span className="text-sm">{e.name}</span>
                  <MonoNumber className="text-[10px] uppercase text-ink-soft">
                    {e.movement_pattern} · {e.equipment}
                  </MonoNumber>
                </button>
              </li>
            ))}
          </ul>
        </div>
      </Sheet>
    </main>
  );
}
