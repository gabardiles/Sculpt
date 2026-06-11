"use client";

import { useEffect, useState } from "react";
import { ArrowRight, Repeat, Sparkles } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { swapExercise } from "@/lib/actions";

export interface CycleReviewData {
  prevCycle: number;
  sessions: number;
  avgFeel: number | null;
  hardAvg: number | null;
  lowDayName: string | null;
  suggestions: {
    programExerciseId: string;
    fromName: string;
    toId: string;
    toName: string;
    toEquipment: string | null;
    reason: string;
  }[];
}

function feelLine(review: CycleReviewData): string {
  if (review.hardAvg != null && review.hardAvg <= 2.5) {
    return (
      "The hard week averaged " +
      review.hardAvg.toFixed(1) +
      " — that's rough. Consider keeping this cycle's medium weights for " +
      "the new hard week, or repeating a medium week. Recovering IS training."
    );
  }
  if (review.avgFeel != null && review.avgFeel >= 4) {
    return (
      "Average feel " +
      review.avgFeel.toFixed(1) +
      " — you're carrying this well. Add weight with confidence this cycle."
    );
  }
  if (review.lowDayName) {
    return (
      review.lowDayName +
      " has been rating low. A small change there can reset the energy."
    );
  }
  return "Solid cycle. Same lifts, heavier — trust the wave.";
}

/**
 * The between-cycles moment: how the cycle felt, and an optional refresh
 * of 1–2 stale accessories. The big lifts always stay — you can't
 * progress what you keep changing.
 */
export function CycleReview({
  review,
  newCycle,
}: {
  review: CycleReviewData;
  newCycle: number;
}) {
  const storageKey = `sculpt-cycle-review-${review.prevCycle}`;
  const [visible, setVisible] = useState(false);
  const [swappedIds, setSwappedIds] = useState<string[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);

  // Dismissal is per-cycle and local — no flash before mount.
  useEffect(() => {
    setVisible(!localStorage.getItem(storageKey));
  }, [storageKey]);

  if (!visible) return null;

  async function doSwap(s: CycleReviewData["suggestions"][number]) {
    if (busyId) return;
    setBusyId(s.programExerciseId);
    await swapExercise(s.programExerciseId, s.toId);
    setSwappedIds((prev) => [...prev, s.programExerciseId]);
    setBusyId(null);
  }

  function dismiss() {
    localStorage.setItem(storageKey, "1");
    setVisible(false);
  }

  return (
    <Card className="hero-gradient overflow-hidden p-5 animate-fade-up">
      <div className="flex items-center gap-2">
        <Sparkles size={16} strokeWidth={1.6} className="text-blush-deep" />
        <Eyebrow>CYCLE {review.prevCycle} COMPLETE</Eyebrow>
      </div>
      <h2 className="mt-1 text-2xl font-light tracking-wide">Strong work.</h2>

      <MonoNumber className="mt-2 block text-xs text-ink-soft">
        {review.sessions} sessions
        {review.avgFeel != null && <> · avg feel {review.avgFeel.toFixed(1)}</>}
      </MonoNumber>

      <p className="mt-3 text-sm font-light leading-relaxed text-ink-soft">
        {feelLine(review)}
      </p>

      {review.suggestions.length > 0 && (
        <div className="mt-4">
          <Eyebrow>KEEP IT FRESH</Eyebrow>
          <ul className="mt-2 flex flex-col gap-2">
            {review.suggestions.map((s) => {
              const done = swappedIds.includes(s.programExerciseId);
              return (
                <li
                  key={s.programExerciseId}
                  className="rounded-2xl bg-white/60 p-3"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="min-w-0 flex-1 text-sm">
                      <span className="font-light">{s.fromName}</span>
                      <ArrowRight
                        size={13}
                        strokeWidth={1.8}
                        className="mx-1.5 inline text-blush-deep"
                      />
                      <span className="font-medium">{s.toName}</span>
                      {s.toEquipment && (
                        <MonoNumber className="ml-1.5 text-[11px] uppercase text-ink-soft">
                          {s.toEquipment}
                        </MonoNumber>
                      )}
                    </span>
                    <PillButton
                      variant={done ? "sage" : "ghost"}
                      className="!min-h-10 shrink-0 !px-4 text-xs"
                      disabled={done || busyId != null}
                      onClick={() => doSwap(s)}
                    >
                      <Repeat size={13} strokeWidth={1.6} />
                      {done ? "Swapped" : busyId === s.programExerciseId ? "…" : "Swap"}
                    </PillButton>
                  </div>
                  <p className="mt-1 text-xs font-light text-ink-soft">
                    {s.reason}
                  </p>
                </li>
              );
            })}
          </ul>
          <p className="mt-2 text-xs font-light text-ink-soft/80">
            Only accessories rotate — the big lifts stay, that&apos;s where
            progress lives.
          </p>
        </div>
      )}

      <PillButton className="mt-4 w-full" onClick={dismiss}>
        Start cycle {newCycle}
        <ArrowRight size={16} strokeWidth={1.8} />
      </PillButton>
    </Card>
  );
}
