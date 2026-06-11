"use client";

import { useCallback, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Camera, Check, PlayCircle, X } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sheet } from "@/components/ui/Sheet";
import { RestTimer } from "@/components/workout/RestTimer";
import { completeWorkout, createFeedPost } from "@/lib/actions";
import { createClient } from "@/lib/supabase/client";
import { dayImage } from "@/lib/editorial";
import { REP_DEFAULT, REP_TARGETS, REST_SECONDS } from "@/lib/cycle";
import type { Phase, RepProfile } from "@/lib/types";
import { formatKg } from "@/lib/format";
import { cn } from "@/lib/cn";

export interface WorkoutExercise {
  programExerciseId: string;
  exerciseId: string;
  name: string;
  shortLabel: string | null;
  muscleGroup: string;
  equipment: string | null;
  unit: "kg" | "s";
  repProfile: RepProfile;
  cue: string | null;
  instructionUrl: string | null;
  imageUrl: string | null;
  sets: number;
  lastWeight: number | null;
  lastReps: number | null;
  lastSets: number | null;
  prevCycleWeight: number | null;
}

interface EntryState {
  weight: string; // text so she can type freely; parsed on save
  reps: string;
  sets: string;
  done: boolean;
}

export function WorkoutClient({
  day,
  phase,
  cycle,
  weekIndex,
  exercises,
  alreadyDone,
  rationale,
  sharePrompt,
  userId,
}: {
  day: { id: string; name: string; index: number };
  phase: Phase;
  cycle: number;
  weekIndex: number;
  exercises: WorkoutExercise[];
  alreadyDone: boolean;
  rationale: string | null;
  sharePrompt: string;
  userId: string;
}) {
  const router = useRouter();
  const [entries, setEntries] = useState<Record<string, EntryState>>(() =>
    Object.fromEntries(
      exercises.map((ex) => [
        ex.exerciseId,
        {
          // Timed holds log seconds in the weight field — prefill the
          // phase's target hold when there's no history.
          weight:
            ex.lastWeight != null
              ? String(ex.lastWeight)
              : ex.unit === "s"
                ? String(REP_DEFAULT.timed[phase])
                : "",
          reps: String(ex.unit === "s" ? "" : REP_DEFAULT[ex.repProfile][phase]),
          sets: String(ex.lastSets ?? ex.sets),
          done: false,
        },
      ])
    )
  );
  const [expanded, setExpanded] = useState<string | null>(null);
  const [videoFor, setVideoFor] = useState<WorkoutExercise | null>(null);
  const [feelOpen, setFeelOpen] = useState(false);
  const [feel, setFeel] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [celebrating, setCelebrating] = useState(false);
  const [sharing, setSharing] = useState(false);
  const [shared, setShared] = useState(false);
  const shareFileRef = useRef<HTMLInputElement>(null);
  const [restKey, setRestKey] = useState(0);
  const [restUntil, setRestUntil] = useState<number | null>(null);

  const doneCount = useMemo(
    () => Object.values(entries).filter((e) => e.done).length,
    [entries]
  );
  const allDone = doneCount === exercises.length;

  // The one to attack next: first exercise not yet done.
  const nextUp = exercises.find((x) => !entries[x.exerciseId].done) ?? null;
  const cardRefs = useRef<Record<string, HTMLLIElement | null>>({});

  const update = useCallback(
    (id: string, patch: Partial<EntryState>) =>
      setEntries((prev) => ({ ...prev, [id]: { ...prev[id], ...patch } })),
    []
  );

  function markDone(ex: WorkoutExercise, isLast: boolean) {
    update(ex.exerciseId, { done: true });
    // Hand the spotlight straight to the next exercise: open it and
    // bring it into view — rest now, but you know where you're going.
    const next =
      exercises.find(
        (x) => x.exerciseId !== ex.exerciseId && !entries[x.exerciseId].done
      ) ?? null;
    setExpanded(next?.exerciseId ?? null);
    if (next) {
      setTimeout(() => {
        cardRefs.current[next.exerciseId]?.scrollIntoView({
          behavior: "smooth",
          block: "center",
        });
      }, 200);
    }
    if (!isLast) {
      setRestUntil(Date.now() + REST_SECONDS[phase] * 1000);
      setRestKey((k) => k + 1);
    }
  }

  async function save() {
    if (feel == null || saving) return;
    setSaving(true);
    const payload = exercises
      .filter((ex) => entries[ex.exerciseId].done)
      .map((ex) => {
        const e = entries[ex.exerciseId];
        const w = parseFloat(e.weight.replace(",", "."));
        const r = parseInt(e.reps, 10);
        const s = parseInt(e.sets, 10);
        return {
          exerciseId: ex.exerciseId,
          weightKg: Number.isFinite(w) && w > 0 ? w : null,
          reps: Number.isFinite(r) && r > 0 ? r : null,
          sets: Number.isFinite(s) && s > 0 ? s : null,
        };
      });
    const res = await completeWorkout({
      programDayId: day.id,
      phase,
      cycle,
      feel,
      entries: payload,
    });
    if (res.ok) {
      setFeelOpen(false);
      // The celebration doubles as the share moment — no auto-redirect.
      setCelebrating(true);
    } else {
      setSaving(false);
    }
  }

  async function shareSelfie(file: File) {
    setSharing(true);
    try {
      const supabase = createClient();
      const ext = file.name.split(".").pop() || "jpg";
      const path = `${userId}/${Date.now()}.${ext}`;
      const { error } = await supabase.storage
        .from("feed-photos")
        .upload(path, file, { contentType: file.type });
      if (!error) {
        await createFeedPost({
          type: "photo",
          body: `${day.name} — done ✓`,
          storagePath: path,
        });
        setShared(true);
        setTimeout(() => router.replace("/"), 1200);
      }
    } finally {
      setSharing(false);
    }
  }

  return (
    <main className="animate-fade-in">
      <header className="flex items-center justify-between">
        <Link
          href="/"
          aria-label="Back"
          className="-ml-2 flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
        >
          <ArrowLeft size={20} strokeWidth={1.5} />
        </Link>
        <MonoNumber className="text-xs uppercase tracking-[0.14em] text-ink-soft">
          CYCLE {cycle} · WEEK {weekIndex} · {phase.toUpperCase()}
        </MonoNumber>
        <div className="w-12" />
      </header>

      {/* editorial banner — big number, attitude */}
      <div className="relative mt-2 h-52 overflow-hidden rounded-[22px]">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={dayImage(day.index)}
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-ink/85 via-ink/25 to-ink/10" />
        <MonoNumber
          aria-hidden
          className="absolute -top-3 right-3 text-[96px] font-light leading-none text-white/25"
        >
          {day.index}
        </MonoNumber>
        <div className="absolute inset-x-0 bottom-0 p-5">
          <Eyebrow className="text-white/75">
            DAY {day.index} · {phase.toUpperCase()} WEEK
          </Eyebrow>
          <h1 className="mt-1 text-4xl font-light tracking-wide text-white">
            {day.name}
          </h1>
        </div>
      </div>

      <div className="mt-3">
        <MonoNumber className="block text-xs text-ink-soft">
          {REP_TARGETS.strength[phase]} reps · 3 sets · {doneCount}/
          {exercises.length} done
        </MonoNumber>
        {/* session progress — fills sage as the work gets done */}
        <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/60">
          <div
            className="h-full rounded-full bg-sage transition-[width] duration-500"
            style={{ width: `${(doneCount / exercises.length) * 100}%` }}
          />
        </div>
        {rationale && (
          <p className="mt-3 text-sm font-light leading-relaxed text-ink-soft">
            {rationale}
          </p>
        )}
        {alreadyDone && (
          <p className="mt-2 text-xs text-sage-deep">
            Already logged this week — logging again adds a second session.
          </p>
        )}
      </div>

      <ul className="mt-6 flex flex-col gap-3">
        {exercises.map((ex) => {
          const e = entries[ex.exerciseId];
          const isOpen = expanded === ex.exerciseId;
          const trendUp =
            ex.lastWeight != null &&
            ex.prevCycleWeight != null &&
            ex.lastWeight > ex.prevCycleWeight;
          return (
            <li
              key={ex.exerciseId}
              ref={(el) => {
                cardRefs.current[ex.exerciseId] = el;
              }}
            >
              <Card
                done={e.done}
                className={cn(
                  "overflow-hidden transition-shadow duration-300",
                  // The next one up gets the spotlight — ringed, lifted,
                  // unmistakable. We're at the gym. Let's go.
                  !e.done &&
                    ex.exerciseId === nextUp?.exerciseId &&
                    "ring-2 ring-blush-deep shadow-[0_10px_36px_rgba(185,125,119,0.30)]"
                )}
              >
                <button
                  className="flex w-full items-center gap-3 px-5 py-4 text-left min-h-12"
                  onClick={() =>
                    setExpanded(isOpen ? null : ex.exerciseId)
                  }
                >
                  {/* done check — the sage moment */}
                  <span
                    className={cn(
                      "flex h-7 w-7 shrink-0 items-center justify-center rounded-full border transition-colors duration-300",
                      e.done
                        ? "border-sage bg-sage text-white"
                        : "border-ink/15 bg-white/40 text-transparent"
                    )}
                  >
                    {e.done && (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                        <path
                          d="M4 12.5 9.5 18 20 6.5"
                          stroke="currentColor"
                          strokeWidth="2.5"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          className="check-draw"
                        />
                      </svg>
                    )}
                  </span>

                  <span className="flex-1 min-w-0">
                    <span className="block truncate font-normal">
                      {!e.done && ex.exerciseId === nextUp?.exerciseId && (
                        <MonoNumber className="mr-2 rounded-full bg-blush-deep px-2 py-0.5 text-[11px] font-medium uppercase tracking-wider text-white">
                          NEXT
                        </MonoNumber>
                      )}
                      {ex.name}
                      {ex.shortLabel && (
                        <MonoNumber className="ml-2 text-[11px] uppercase text-ink-soft">
                          {ex.shortLabel}
                        </MonoNumber>
                      )}
                    </span>
                    <MonoNumber className="mt-0.5 block text-xs uppercase tracking-wider text-ink-soft">
                      {ex.muscleGroup}
                      {ex.lastWeight != null && (
                        <>
                          {/* e.g. LAST: 12 kg × 12 × 3 */}
                          {" "}· LAST: {formatKg(ex.lastWeight)} {ex.unit}
                          {ex.unit === "kg" && ex.lastReps != null && (
                            <> × {ex.lastReps} × {ex.lastSets ?? ex.sets}</>
                          )}
                          {trendUp && <span className="text-sage-deep"> ↑</span>}
                        </>
                      )}
                    </MonoNumber>
                  </span>

                  <span
                    role="button"
                    tabIndex={0}
                    aria-label={`How to do ${ex.name}`}
                    className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
                    onClick={(ev) => {
                      ev.stopPropagation();
                      setVideoFor(ex);
                    }}
                    onKeyDown={(ev) => {
                      if (ev.key === "Enter" || ev.key === " ") {
                        ev.stopPropagation();
                        setVideoFor(ex);
                      }
                    }}
                  >
                    <PlayCircle size={20} strokeWidth={1.4} />
                  </span>
                </button>

                {/* expanded logging panel — KG / REP / SET, that's it */}
                {isOpen && (
                  <div className="border-t border-white/50 px-5 py-4 animate-fade-up">
                    <div className="grid grid-cols-3 gap-2">
                      <label className="block">
                        <span className="eyebrow block text-center">
                          {ex.unit === "s" ? "SEC" : "KG"}
                        </span>
                        <input
                          type="number"
                          inputMode="decimal"
                          step="0.5"
                          min="0"
                          placeholder="—"
                          value={e.weight}
                          onChange={(ev) =>
                            update(ex.exerciseId, { weight: ev.target.value })
                          }
                          className="mt-1 h-16 w-full rounded-2xl border border-ink/15 bg-white/70 text-center font-mono text-2xl font-light outline-none focus:border-blush-deep placeholder:text-ink/30"
                        />
                      </label>
                      {ex.unit === "kg" && (
                        <label className="block">
                          <span className="eyebrow block text-center">REP</span>
                          <input
                            type="number"
                            inputMode="numeric"
                            min="0"
                            placeholder="—"
                            value={e.reps}
                            onChange={(ev) =>
                              update(ex.exerciseId, { reps: ev.target.value })
                            }
                            className="mt-1 h-16 w-full rounded-2xl border border-ink/15 bg-white/70 text-center font-mono text-2xl font-light outline-none focus:border-blush-deep placeholder:text-ink/30"
                          />
                        </label>
                      )}
                      <label className="block">
                        <span className="eyebrow block text-center">SET</span>
                        <input
                          type="number"
                          inputMode="numeric"
                          min="0"
                          placeholder="—"
                          value={e.sets}
                          onChange={(ev) =>
                            update(ex.exerciseId, { sets: ev.target.value })
                          }
                          className="mt-1 h-16 w-full rounded-2xl border border-ink/15 bg-white/70 text-center font-mono text-2xl font-light outline-none focus:border-blush-deep placeholder:text-ink/30"
                        />
                      </label>
                    </div>

                    <MonoNumber className="mt-2 block text-center text-xs text-ink-soft/80">
                      target {REP_TARGETS[ex.repProfile][phase]}
                      {ex.unit === "s" ? " hold" : " reps"}
                    </MonoNumber>

                    <div className="mt-4 flex gap-2">
                      {e.done ? (
                        <PillButton
                          variant="ghost"
                          className="flex-1"
                          onClick={() => update(ex.exerciseId, { done: false })}
                        >
                          <X size={16} strokeWidth={1.5} /> Undo
                        </PillButton>
                      ) : (
                        <PillButton
                          variant="sage"
                          className="flex-1"
                          onClick={() =>
                            markDone(
                              ex,
                              doneCount + 1 === exercises.length
                            )
                          }
                        >
                          <Check size={16} strokeWidth={2} /> Done
                        </PillButton>
                      )}
                    </div>
                  </div>
                )}
              </Card>
            </li>
          );
        })}
      </ul>

      {/* rest timer — sticky tag at the top, out of the way */}
      {restUntil && (
        <div className="fixed inset-x-0 top-[max(0.75rem,env(safe-area-inset-top))] z-40 flex justify-center px-5">
          <RestTimer
            key={restKey}
            until={restUntil}
            nextName={nextUp?.name ?? null}
            onDismiss={() => setRestUntil(null)}
          />
        </div>
      )}

      {/* finish bar */}
      {doneCount > 0 && (
        <div className="fixed inset-x-0 bottom-24 z-30 px-5">
          {/* frosted wrapper: heavy white + blur so nothing bleeds through */}
          <div className="mx-auto max-w-md rounded-full bg-white/85 backdrop-blur-2xl shadow-lg shadow-ink/10">
            <PillButton
              className="w-full"
              variant={allDone ? "primary" : "ghost"}
              onClick={() => setFeelOpen(true)}
            >
              Finish workout
              <MonoNumber className="text-xs">
                {doneCount}/{exercises.length}
              </MonoNumber>
            </PillButton>
          </div>
        </div>
      )}

      {/* instruction sheet — hidden until wanted */}
      <Sheet
        open={videoFor != null}
        onClose={() => setVideoFor(null)}
        title={videoFor?.name}
      >
        {videoFor && (
          <div className="pb-2">
            {videoFor.instructionUrl ? (
              <div className="aspect-video w-full overflow-hidden rounded-2xl bg-ink/5">
                <iframe
                  src={videoFor.instructionUrl}
                  title={videoFor.name}
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowFullScreen
                  className="h-full w-full"
                />
              </div>
            ) : videoFor.imageUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={videoFor.imageUrl}
                alt={videoFor.name}
                className="w-full rounded-2xl"
              />
            ) : null}
            <div className="mt-4 flex items-center gap-2">
              <MonoNumber className="rounded-full bg-blush/40 px-3 py-1 text-[11px] uppercase tracking-wider">
                {videoFor.muscleGroup}
              </MonoNumber>
              {videoFor.equipment && (
                <MonoNumber className="rounded-full bg-white/60 px-3 py-1 text-[11px] uppercase tracking-wider text-ink-soft">
                  {videoFor.equipment}
                </MonoNumber>
              )}
            </div>
            {videoFor.cue && (
              <p className="mt-3 text-sm font-light leading-relaxed text-ink-soft">
                {videoFor.cue}
              </p>
            )}
          </div>
        )}
      </Sheet>

      {/* feel rating — the closing moment */}
      <Sheet open={feelOpen} onClose={() => !saving && setFeelOpen(false)} title="">
        <div className="pb-4 text-center">
          <Eyebrow>SESSION COMPLETE</Eyebrow>
          <h2 className="mt-2 text-2xl font-light tracking-wide">
            How did it feel?
          </h2>
          <div className="mt-8 flex items-center justify-center gap-3">
            {[1, 2, 3, 4, 5].map((n) => (
              <button
                key={n}
                aria-label={`Feel ${n} of 5`}
                onClick={() => setFeel(n)}
                className={cn(
                  "flex h-12 w-12 items-center justify-center rounded-full border font-mono text-sm transition-all duration-150",
                  feel === n
                    ? "scale-110 border-blush-deep bg-blush text-ink"
                    : "border-ink/15 bg-white/50 text-ink-soft"
                )}
              >
                {n}
              </button>
            ))}
          </div>
          <div className="mt-2 flex justify-between px-2 text-[11px] text-ink-soft/80">
            <span>rough</span>
            <span>unstoppable</span>
          </div>
          <PillButton
            className="mt-8 w-full"
            disabled={feel == null || saving}
            onClick={save}
          >
            {saving ? "Saving…" : "Save session"}
          </PillButton>
        </div>
      </Sheet>

      {/* sage completion — the dopamine moment, then the share moment */}
      {celebrating && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-bg/95 backdrop-blur-md px-6">
          <input
            ref={shareFileRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) shareSelfie(f);
            }}
          />
          <div className="flex w-full max-w-sm flex-col items-center animate-fade-up">
            <span className="flex h-24 w-24 items-center justify-center rounded-full bg-sage">
              <svg width="44" height="44" viewBox="0 0 24 24" fill="none">
                <path
                  d="M4 12.5 9.5 18 20 6.5"
                  stroke="white"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  className="check-draw"
                />
              </svg>
            </span>
            <p className="mt-5 text-2xl font-light tracking-wide">
              {day.name} — done
            </p>
            {shared ? (
              <p className="mt-4 text-sm font-medium text-sage-deep">
                Shared with your friends ✓
              </p>
            ) : (
              <>
                <p className="mt-3 text-center text-sm font-light leading-relaxed text-ink-soft">
                  {sharePrompt}
                </p>
                <PillButton
                  className="mt-6 w-full"
                  disabled={sharing}
                  onClick={() => shareFileRef.current?.click()}
                >
                  <Camera size={17} strokeWidth={1.6} />
                  {sharing ? "Posting…" : "Snap it for the feed"}
                </PillButton>
                <button
                  onClick={() => router.replace("/")}
                  className="mt-3 min-h-12 text-sm font-light text-ink-soft underline-offset-4 active:underline"
                >
                  Not today
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </main>
  );
}
