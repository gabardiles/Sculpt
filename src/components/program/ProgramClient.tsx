"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  Check,
  CircleHelp,
  MoreHorizontal,
  Pencil,
  Plus,
  Repeat,
  Search,
  Star,
  Trash2,
} from "lucide-react";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sheet } from "@/components/ui/Sheet";
import {
  addExercise,
  createCustomExercise,
  updateCustomExercise,
  deleteCustomExercise,
  removeExercise,
  resetCycle,
  restartProgram,
  swapExercise,
  switchProgram,
} from "@/lib/actions";
import { REP_TARGETS, type CycleSummary } from "@/lib/cycle";
import { INTENSITY_LABEL, SESSION_LABEL, WEEKDAY_LABEL } from "@/lib/schedule";
import type { Exercise, Phase, SessionType, WeekIntensity } from "@/lib/types";
import { formatDay, formatRange } from "@/lib/format";
import { cn } from "@/lib/cn";

interface ExerciseRow {
  programExerciseId: string;
  sort: number;
  scheme?: string | null;
  /** Part of the fitness-report goal-focus block. */
  isFocus?: boolean;
  exercise: Exercise;
}

interface DayRow {
  id: string;
  index: number;
  name: string;
  exercises: ExerciseRow[];
}

/** One prescribed week of a fixed-schedule (Hybrid) program. */
export interface FixedWeekRow {
  index: number;
  intensity: WeekIntensity;
  label: string | null;
  note: string | null;
  status: "star" | "check" | "open";
  days: (DayRow & {
    sessionType: SessionType;
    weekday: number | null;
    doneAt: string | null;
  })[];
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
  weekStatus,
  fixed = null,
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
  weekStatus: Record<Phase, "star" | "check" | "open">;
  fixed?: {
    weeks: FixedWeekRow[];
    currentWeekIndex: number;
    totalWeeks: number;
  } | null;
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
  const [helpOpen, setHelpOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);
  // When set, the exercise sheet is editing one of your own exercises.
  const [editEx, setEditEx] = useState<Exercise | null>(null);

  function openCreate() {
    setEditEx(null);
    setCreateError(null);
    setCreateOpen(true);
  }
  function openEdit(e: Exercise) {
    setSwapFor(null);
    setAddFor(null);
    setEditEx(e);
    setCreateError(null);
    setCreateOpen(true);
  }
  function closeForm() {
    setCreateOpen(false);
    setEditEx(null);
    setCreateError(null);
  }

  async function doDeleteExercise() {
    if (!editEx || busy) return;
    setBusy(true);
    const res = await deleteCustomExercise(editEx.id);
    setBusy(false);
    if (res.ok) closeForm();
    else setCreateError(res.error);
  }
  const [confirmSwitch, setConfirmSwitch] = useState<string | null>(null);
  const [confirmRestart, setConfirmRestart] = useState(false);
  const [expandedWeek, setExpandedWeek] = useState<number | null>(
    fixed?.currentWeekIndex ?? null
  );

  const TEMPLATES = ["Lean & Sculpted", "Strong & Built", "Hybrid Athlete"];
  const otherTemplates = TEMPLATES.filter((t) => t !== program.name);

  async function doSwitch(template: string) {
    if (busy) return;
    setBusy(true);
    await switchProgram(template);
    setConfirmSwitch(null);
    setBusy(false);
  }

  // The guardrail: only same movement pattern + same primary muscle group.
  // Same training role (rep_profile) comes first — a heavy compound and a
  // pump finisher are not real substitutes, even when the muscle matches.
  // Your own exercises sort to the top of every picker (library is already
  // name-sorted, and Array.sort is stable, so names stay ordered within each
  // group).
  const mineFirst = (arr: Exercise[]) =>
    [...arr].sort((a, b) => Number(a.is_global) - Number(b.is_global));

  const swapOptions = useMemo(() => {
    if (!swapFor) return { sameTier: [], otherTier: [] };
    const compatible = library.filter(
      (e) =>
        e.id !== swapFor.exercise.id &&
        e.movement_pattern === swapFor.exercise.movement_pattern &&
        e.muscle_group === swapFor.exercise.muscle_group
    );
    return {
      sameTier: mineFirst(
        compatible.filter((e) => e.rep_profile === swapFor.exercise.rep_profile)
      ),
      otherTier: mineFirst(
        compatible.filter((e) => e.rep_profile !== swapFor.exercise.rep_profile)
      ),
    };
  }, [swapFor, library]);

  const addOptions = useMemo(() => {
    if (!addFor) return [];
    const q = search.trim().toLowerCase();
    const inDay = new Set(addFor.exercises.map((x) => x.exercise.id));
    return mineFirst(
      library
        .filter((e) => !inDay.has(e.id))
        .filter(
          (e) =>
            !q ||
            e.name.toLowerCase().includes(q) ||
            e.muscle_group.includes(q) ||
            e.movement_pattern.includes(q)
        )
    ).slice(0, 30);
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

  // Shared picker row — custom exercises get a "Yours" tag and an edit pencil.
  function renderOption(
    e: Exercise,
    onPick: (id: string) => void,
    meta: string | null,
    dim = false
  ) {
    return (
      <li key={e.id} className="flex items-stretch gap-1.5">
        <button
          onClick={() => onPick(e.id)}
          disabled={busy}
          className={cn(
            "glass flex flex-1 items-center justify-between gap-2 px-4 py-3 min-h-12 text-left active:scale-[0.99] transition-transform",
            dim && "opacity-80"
          )}
        >
          <span className="flex min-w-0 items-center gap-2 text-sm">
            <span className="truncate">{e.name}</span>
            {!e.is_global && (
              <span className="shrink-0 rounded-full bg-blush/40 px-2 py-0.5 text-[10px] uppercase tracking-wider text-blush-deep">
                Yours
              </span>
            )}
          </span>
          <MonoNumber className="shrink-0 text-[11px] uppercase text-ink-soft">
            {meta}
          </MonoNumber>
        </button>
        {!e.is_global && (
          <button
            type="button"
            aria-label={`Edit ${e.name}`}
            onClick={() => openEdit(e)}
            className="glass flex w-11 shrink-0 items-center justify-center rounded-2xl text-ink-soft active:bg-ink/5"
          >
            <Pencil size={15} strokeWidth={1.5} />
          </button>
        )}
      </li>
    );
  }

  async function doRestart() {
    if (busy) return;
    setBusy(true);
    await restartProgram();
    setConfirmRestart(false);
    setMenuOpen(false);
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
          <MonoNumber className="mt-1 block text-xs uppercase tracking-[0.14em] text-ink-soft">
            {fixed
              ? `WEEK ${fixed.currentWeekIndex} OF ${fixed.totalWeeks}`
              : `CYCLE ${cycle} · ${currentPhase.toUpperCase()} WEEK`}
          </MonoNumber>
        </div>
        <div className="flex items-center">
          <button
            aria-label="Help — how editing works"
            onClick={() => setHelpOpen(true)}
            className="flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
          >
            <CircleHelp size={18} strokeWidth={1.5} />
          </button>
          <button
            aria-label={editing ? "Done editing" : "Edit program"}
            onClick={() => setEditing(!editing)}
            className={cn(
              "flex h-12 w-12 items-center justify-center rounded-full transition-colors",
              editing ? "bg-blush text-on-accent" : "text-ink-soft active:bg-ink/5"
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

      {/* fixed schedule — 20 prescribed weeks, current one expanded */}
      {fixed && (
        <div className="mt-6 flex flex-col gap-3">
          {fixed.weeks.map((week) => {
            const isCurrent = week.index === fixed.currentWeekIndex;
            const isOpen = expandedWeek === week.index;
            return (
              <section key={week.index}>
                <button
                  className="flex w-full items-center justify-between gap-2 min-h-10 py-1"
                  onClick={() => setExpandedWeek(isOpen ? null : week.index)}
                >
                  <span className="flex items-center gap-1.5">
                    <MonoNumber
                      className={cn(
                        "text-xs uppercase tracking-[0.14em]",
                        isCurrent ? "text-blush-deep" : "text-ink-soft"
                      )}
                    >
                      WEEK {week.index} · {INTENSITY_LABEL[week.intensity]}
                    </MonoNumber>
                    {week.label && (
                      <MonoNumber className="rounded-full bg-blush/30 px-2 py-0.5 text-[10px] uppercase tracking-wider text-blush-deep">
                        {week.label}
                      </MonoNumber>
                    )}
                    {week.status === "star" && (
                      <Star
                        size={14}
                        strokeWidth={1.8}
                        className="fill-blush-deep text-blush-deep"
                        aria-label="Every session done"
                      />
                    )}
                    {week.status === "check" && (
                      <Check
                        size={14}
                        strokeWidth={2.2}
                        className="text-sage-deep"
                        aria-label="Week completed"
                      />
                    )}
                  </span>
                  <MonoNumber className="text-xs text-ink-soft">
                    {week.days.length} sessions
                  </MonoNumber>
                </button>

                {isOpen && (
                  <div className="mt-1 flex flex-col gap-3">
                    {week.note && (
                      <p className="text-sm font-light leading-relaxed text-ink-soft">
                        {week.note}
                      </p>
                    )}
                    {week.days.map((day) => (
                      <Card key={day.id} done={!!day.doneAt} className="overflow-hidden">
                        <Link
                          href={`/workout/${day.id}`}
                          className="flex items-center justify-between px-5 py-4 min-h-12"
                        >
                          <div>
                            <Eyebrow>
                              {day.weekday
                                ? WEEKDAY_LABEL[day.weekday - 1].toUpperCase()
                                : `DAY ${day.index}`}{" "}
                              · {SESSION_LABEL[day.sessionType].toUpperCase()}
                            </Eyebrow>
                            <p className="mt-0.5 font-normal">{day.name}</p>
                          </div>
                          {day.doneAt ? (
                            <MonoNumber className="text-xs text-sage-deep">
                              {formatDay(day.doneAt)}
                            </MonoNumber>
                          ) : (
                            <MonoNumber className="text-xs text-ink-soft">
                              {day.exercises.length > 0
                                ? `${day.exercises.length} exercises`
                                : "written session"}
                            </MonoNumber>
                          )}
                        </Link>

                        {day.exercises.length > 0 && (
                          <ul className="border-t border-edge px-5 py-2">
                            {day.exercises.map((row) => (
                              <li
                                key={row.programExerciseId}
                                className="flex items-center justify-between gap-2 py-1.5"
                              >
                                <span className="min-w-0 flex-1">
                                  <span className="flex items-center gap-1.5 text-sm font-light">
                                    <span className="truncate">
                                      {row.exercise.name}
                                    </span>
                                    {row.isFocus && (
                                      <span className="shrink-0 rounded-full bg-blush/40 px-1.5 py-0.5 text-[9px] uppercase tracking-wider text-blush-deep">
                                        Goal
                                      </span>
                                    )}
                                  </span>
                                  {row.scheme && (
                                    <MonoNumber className="block truncate text-[11px] text-ink-soft/80">
                                      {row.scheme}
                                    </MonoNumber>
                                  )}
                                </span>
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
                    ))}
                  </div>
                )}
              </section>
            );
          })}
        </div>
      )}

      {/* the 3-week cycle, stacked */}
      {!fixed && (
      <div className="mt-6 flex flex-col gap-8">
        {phases.map((phase, wi) => {
          const stamps = doneStamps[phase];
          const isCurrent = phase === currentPhase;
          return (
            <section key={phase}>
              <div className="flex items-baseline justify-between">
                <h2 className="flex items-center gap-1.5 font-light tracking-wide">
                  <MonoNumber
                    className={cn(
                      "text-xs uppercase tracking-[0.14em]",
                      isCurrent ? "text-blush-deep" : "text-ink-soft"
                    )}
                  >
                    WEEK {wi + 1} · {phase.toUpperCase()}
                  </MonoNumber>
                  {weekStatus[phase] === "star" && (
                    <Star
                      size={14}
                      strokeWidth={1.8}
                      className="fill-blush-deep text-blush-deep"
                      aria-label="All five sessions"
                    />
                  )}
                  {weekStatus[phase] === "check" && (
                    <Check
                      size={14}
                      strokeWidth={2.2}
                      className="text-sage-deep"
                      aria-label="Week completed"
                    />
                  )}
                </h2>
                <MonoNumber className="text-xs text-ink-soft">
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
                        <ul className="border-t border-edge px-5 py-2">
                          {day.exercises.map((row) => (
                            <li
                              key={row.programExerciseId}
                              className="flex items-center justify-between gap-2 py-1.5"
                            >
                              <span className="flex min-w-0 flex-1 items-center gap-1.5 text-sm font-light">
                                <span className="truncate">{row.exercise.name}</span>
                                {row.isFocus && (
                                  <span className="shrink-0 rounded-full bg-blush/40 px-1.5 py-0.5 text-[9px] uppercase tracking-wider text-blush-deep">
                                    Goal
                                  </span>
                                )}
                              </span>
                              <MonoNumber className="text-[11px] uppercase text-ink-soft/70">
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
      )}

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

      {/* switch program — visible, small, with an honest warning */}
      {otherTemplates.length > 0 && (
        <section className="mt-8 flex flex-col gap-2">
          {otherTemplates.map((template) => (
            <Card key={template} className="flex items-center gap-3 px-4 py-3">
              <Repeat
                size={16}
                strokeWidth={1.5}
                className="shrink-0 text-ink-soft"
              />
              <span className="min-w-0 flex-1 text-xs font-light leading-snug text-ink-soft">
                {confirmSwitch === template ? (
                  <>
                    Replace <span className="font-medium">{program.name}</span>{" "}
                    with {template}? Your history is kept, but the new program
                    starts from the beginning.
                  </>
                ) : (
                  <>
                    Prefer {template}? Switching replaces your current program
                    — history stays.
                  </>
                )}
              </span>
              {confirmSwitch === template ? (
                <span className="flex shrink-0 items-center gap-1.5">
                  <button
                    disabled={busy}
                    onClick={() => doSwitch(template)}
                    className="rounded-full bg-blush px-3 py-2 text-xs font-medium text-on-accent disabled:opacity-40"
                  >
                    {busy ? "…" : "Yes, switch"}
                  </button>
                  <button
                    onClick={() => setConfirmSwitch(null)}
                    className="rounded-full px-2 py-2 text-xs font-light text-ink-soft"
                  >
                    Cancel
                  </button>
                </span>
              ) : (
                <button
                  onClick={() => setConfirmSwitch(template)}
                  className="shrink-0 rounded-full border border-ink/15 bg-surface-soft px-3 py-2 text-xs text-ink-soft active:bg-ink/5"
                >
                  Switch
                </button>
              )}
            </Card>
          ))}
        </section>
      )}

      {/* small menu — manual reset / restart live here, out of the way */}
      <Sheet open={menuOpen} onClose={() => setMenuOpen(false)} title="Program">
        <div className="flex flex-col gap-3 pb-2">
          {fixed ? (
            <p className="text-sm font-light text-ink-soft">
              This program runs on a fixed 20-week schedule — there is no cycle
              to reset.
            </p>
          ) : (
            <>
              <p className="text-sm font-light text-ink-soft">
                Resetting starts cycle {cycle + 1} at a light week. Logged
                history stays.
              </p>
              <PillButton variant="ghost" onClick={doReset} disabled={busy}>
                Reset cycle
              </PillButton>
            </>
          )}

          {/* restart — wipe every added/swapped exercise, start fresh */}
          <div className="mt-2 border-t border-edge pt-3">
            <p className="text-sm font-light leading-relaxed text-ink-soft">
              {confirmRestart ? (
                <>
                  Restart <span className="font-medium">{program.name}</span>{" "}
                  from scratch? Every added, swapped and goal-focus exercise is
                  removed and the program returns to its original plan, back at
                  the start. Your logged history stays.
                </>
              ) : (
                <>
                  Things got messy? Restart rebuilds the program from its
                  original plan — clearing all your added and goal-focus
                  exercises. History is kept.
                </>
              )}
            </p>
            {confirmRestart ? (
              <div className="mt-3 flex gap-2">
                <PillButton
                  className="flex-1"
                  disabled={busy}
                  onClick={doRestart}
                >
                  {busy ? "Rebuilding…" : "Yes, start fresh"}
                </PillButton>
                <PillButton
                  variant="ghost"
                  onClick={() => setConfirmRestart(false)}
                  disabled={busy}
                >
                  Cancel
                </PillButton>
              </div>
            ) : (
              <PillButton
                variant="ghost"
                className="mt-3 text-blush-deep"
                onClick={() => setConfirmRestart(true)}
              >
                <Trash2 size={15} strokeWidth={1.5} /> Restart program
              </PillButton>
            )}
          </div>
        </div>
      </Sheet>

      {/* help — how editing works */}
      <Sheet open={helpOpen} onClose={() => setHelpOpen(false)} title="How this works">
        <div className="flex flex-col gap-4 pb-2 text-sm font-light leading-relaxed text-ink-soft">
          <p>
            <span className="font-medium text-ink">Edit your program.</span>{" "}
            Tap the pencil up top. Every exercise gets a{" "}
            <Repeat size={13} className="inline text-blush-deep" /> swap icon —
            you&apos;ll only ever be offered exercises that train the same
            muscle with the same movement, so the program stays balanced no
            matter what you change. Same-role options come first; machines and
            free weights are interchangeable.
          </p>
          <p>
            <span className="font-medium text-ink">Add or remove.</span> In
            edit mode each day has an “Add exercise” row and a{" "}
            <Trash2 size={13} className="inline" /> on every exercise. Removing
            never deletes your logged history.
          </p>
          <p>
            <span className="font-medium text-ink">Your own exercises.</span>{" "}
            Missing something your gym has? Create it below — name it, say
            what it trains, and it joins your library (only you see it). Paste
            a YouTube link if you want the video behind the play button. Reps
            are automatic: the 3-week wave sets them from the training role
            you pick.
          </p>
          <PillButton
            variant="ghost"
            onClick={() => {
              setHelpOpen(false);
              openCreate();
            }}
          >
            <Plus size={16} strokeWidth={1.5} /> Create your own exercise
          </PillButton>
        </div>
      </Sheet>

      {/* create / edit your own exercise */}
      <Sheet
        open={createOpen}
        onClose={closeForm}
        title={editEx ? "Edit exercise" : "Your own exercise"}
      >
        <form
          key={editEx?.id ?? "new"}
          action={async (fd) => {
            setCreateError(null);
            const res = editEx
              ? await updateCustomExercise(fd)
              : await createCustomExercise(fd);
            if (res.ok) {
              closeForm();
            } else {
              setCreateError(res.error);
            }
          }}
          className="flex flex-col gap-3 pb-2"
        >
          {editEx && <input type="hidden" name="id" value={editEx.id} />}
          <input
            name="name"
            required
            maxLength={60}
            defaultValue={editEx?.name ?? ""}
            placeholder="Exercise name"
            className="h-12 rounded-full border border-ink/15 bg-surface px-5 text-sm outline-none focus:border-blush-deep"
          />
          <div className="flex gap-2">
            <select
              name="muscle_group"
              required
              defaultValue={editEx?.muscle_group ?? ""}
              className="h-12 min-w-0 flex-1 rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none"
            >
              <option value="" disabled>
                Muscle
              </option>
              {[
                "glutes",
                "hamstrings",
                "quads",
                "back",
                "chest",
                "shoulders",
                "arms",
                "core",
                "calves",
              ].map((m) => (
                <option key={m} value={m}>
                  {m}
                </option>
              ))}
            </select>
            <select
              name="movement_pattern"
              required
              defaultValue={editEx?.movement_pattern ?? ""}
              className="h-12 min-w-0 flex-1 rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none"
            >
              <option value="" disabled>
                Movement
              </option>
              {[
                "hinge",
                "squat",
                "lunge",
                "thrust",
                "abduction",
                "push",
                "pull",
                "core",
                "accessory",
              ].map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          </div>
          <select
            name="rep_profile"
            required
            defaultValue={editEx?.rep_profile ?? ""}
            className="h-12 rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none"
          >
            <option value="" disabled>
              Training role — sets your reps automatically
            </option>
            <option value="strength">Heavy — 10–12 / 6–8 / 4–6 reps</option>
            <option value="pump">Pump — 15–20 / 12–15 / 10–12 reps</option>
            <option value="timed">Timed hold — 30 / 40 / 45 s</option>
          </select>
          <input
            name="equipment"
            maxLength={40}
            defaultValue={editEx?.equipment ?? ""}
            placeholder="Equipment (optional) — e.g. machine, dumbbells"
            className="h-12 rounded-full border border-ink/15 bg-surface px-5 text-sm outline-none focus:border-blush-deep"
          />
          <input
            name="video_url"
            inputMode="url"
            defaultValue={editEx?.instruction_url ?? ""}
            placeholder="YouTube link (optional) — paste it here"
            className="h-12 rounded-full border border-ink/15 bg-surface px-5 text-sm outline-none focus:border-blush-deep"
          />
          {createError && (
            <p className="text-center text-xs text-blush-deep">{createError}</p>
          )}
          <PillButton type="submit">
            {editEx ? "Save changes" : "Save to my library"}
          </PillButton>
          {editEx ? (
            <PillButton
              type="button"
              variant="ghost"
              disabled={busy}
              onClick={doDeleteExercise}
              className="text-blush-deep"
            >
              <Trash2 size={15} strokeWidth={1.5} /> Delete exercise
            </PillButton>
          ) : (
            <p className="text-center text-xs font-light text-ink-soft">
              Only you see your own exercises. Find them when swapping or adding.
            </p>
          )}
        </form>
      </Sheet>

      {/* smart swap — only compatible alternatives */}
      <Sheet
        open={swapFor != null}
        onClose={() => setSwapFor(null)}
        title={`Swap ${swapFor?.exercise.name ?? ""}`}
      >
        <div className="pb-2">
          <MonoNumber className="text-[11px] uppercase tracking-wider text-ink-soft">
            {swapFor?.exercise.movement_pattern} · {swapFor?.exercise.muscle_group}
          </MonoNumber>
          {swapOptions.sameTier.length + swapOptions.otherTier.length === 0 ? (
            <p className="mt-4 text-sm font-light text-ink-soft">
              No equivalent alternatives in the library yet.
            </p>
          ) : (
            <>
              <ul className="mt-3 flex flex-col gap-2">
                {swapOptions.sameTier.map((e) =>
                  renderOption(e, doSwap, e.equipment)
                )}
              </ul>
              {swapOptions.otherTier.length > 0 && (
                <>
                  <MonoNumber className="mt-4 block text-[11px] uppercase tracking-wider text-ink-soft/80">
                    Different intensity
                  </MonoNumber>
                  <ul className="mt-2 flex flex-col gap-2">
                    {swapOptions.otherTier.map((e) =>
                      renderOption(
                        e,
                        doSwap,
                        [e.rep_profile, e.equipment].filter(Boolean).join(" · "),
                        true
                      )
                    )}
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
          <div className="flex items-center gap-2 rounded-full border border-ink/10 bg-surface px-4">
            <Search size={16} strokeWidth={1.5} className="text-ink-soft" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search the library"
              className="h-12 flex-1 bg-transparent text-sm outline-none"
            />
          </div>
          <ul className="mt-3 flex flex-col gap-2">
            {addOptions.map((e) =>
              renderOption(
                e,
                doAdd,
                [e.movement_pattern, e.equipment].filter(Boolean).join(" · ")
              )
            )}
          </ul>
          <button
            onClick={() => {
              setAddFor(null);
              setSearch("");
              openCreate();
            }}
            className="mt-3 flex min-h-11 w-full items-center justify-center gap-2 text-sm font-light text-blush-deep"
          >
            <Plus size={16} strokeWidth={1.5} />
            Not in the list? Create your own
          </button>
        </div>
      </Sheet>
    </main>
  );
}
