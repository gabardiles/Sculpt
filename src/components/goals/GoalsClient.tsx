"use client";

import { useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sheet } from "@/components/ui/Sheet";
import { ProgressRing } from "@/components/ui/ProgressRing";
import { createGoal, deleteGoal } from "@/lib/actions";
import type { Exercise, GoalType } from "@/lib/types";
import { formatDay } from "@/lib/format";

export interface GoalRow {
  id: string;
  type: GoalType;
  label: string;
  progress: number;
  current: string;
  target: string;
  achieved: boolean;
  deadline: string | null;
}

const TYPE_COPY: Record<GoalType, { title: string; hint: string }> = {
  body_weight: { title: "Body weight", hint: "Target weight in kg" },
  exercise_pr: { title: "Exercise PR", hint: "Target weight in kg" },
  consistency: { title: "Consistency", hint: "Workouts per week, for 4 weeks" },
  fitness_score: { title: "Fitness score", hint: "Target score, 1–10" },
};

export function GoalsClient({
  goals,
  library,
}: {
  goals: GoalRow[];
  library: Exercise[];
}) {
  const [adding, setAdding] = useState(false);
  const [type, setType] = useState<GoalType>("body_weight");

  const active = goals.filter((g) => !g.achieved);
  const achieved = goals.filter((g) => g.achieved);

  return (
    <div>
      {active.length === 0 ? (
        <p className="mt-10 text-center text-sm font-light text-ink-soft">
          No goals yet — pick one thing worth chasing.
        </p>
      ) : (
        <ul className="mt-6 flex flex-col gap-3">
          {active.map((g) => (
            <li key={g.id}>
              <Card className="flex items-center gap-4 p-4">
                <ProgressRing progress={g.progress} done={g.progress >= 1}>
                  <MonoNumber className="text-[11px] text-ink-soft">
                    {Math.round(g.progress * 100)}%
                  </MonoNumber>
                </ProgressRing>
                <div className="flex-1 min-w-0">
                  <Eyebrow>{TYPE_COPY[g.type].title}</Eyebrow>
                  <p className="truncate font-light">{g.label}</p>
                  <MonoNumber className="text-xs text-ink-soft">
                    {g.current} → {g.target}
                    {g.deadline && <> · by {formatDay(g.deadline)}</>}
                  </MonoNumber>
                </div>
                <button
                  aria-label={`Delete goal ${g.label}`}
                  onClick={() => deleteGoal(g.id)}
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-ink-soft/80 active:bg-ink/5"
                >
                  <Trash2 size={15} strokeWidth={1.5} />
                </button>
              </Card>
            </li>
          ))}
        </ul>
      )}

      {active.length < 3 && (
        <div className="mt-5 flex justify-center">
          <PillButton variant="ghost" onClick={() => setAdding(true)}>
            <Plus size={16} strokeWidth={1.5} /> New goal
          </PillButton>
        </div>
      )}

      {achieved.length > 0 && (
        <section className="mt-10">
          <Eyebrow>ACHIEVED</Eyebrow>
          <ul className="mt-2 flex flex-col gap-2">
            {achieved.map((g) => (
              <li key={g.id}>
                <Card done className="flex items-center justify-between px-4 py-3">
                  <span className="text-sm font-light">
                    {TYPE_COPY[g.type].title} · {g.label}
                  </span>
                  <MonoNumber className="text-xs text-sage-deep">
                    {g.target} ✓
                  </MonoNumber>
                </Card>
              </li>
            ))}
          </ul>
        </section>
      )}

      <Sheet open={adding} onClose={() => setAdding(false)} title="New goal">
        <form
          action={async (fd) => {
            await createGoal(fd);
            setAdding(false);
          }}
          className="flex flex-col gap-4 pb-2"
        >
          <div className="flex gap-2">
            {(Object.keys(TYPE_COPY) as GoalType[]).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setType(t)}
                className={`flex-1 rounded-full border px-2 py-3 text-xs transition-colors ${
                  type === t
                    ? "border-blush-deep bg-blush/40"
                    : "border-ink/10 bg-surface-soft text-ink-soft"
                }`}
              >
                {TYPE_COPY[t].title}
              </button>
            ))}
          </div>
          <input type="hidden" name="type" value={type} />

          {type === "exercise_pr" && (
            <select
              name="exercise_id"
              required
              className="h-12 rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none"
              defaultValue=""
            >
              <option value="" disabled>
                Pick an exercise
              </option>
              {library
                .filter((e) => e.unit === "kg")
                .map((e) => (
                  <option key={e.id} value={e.id}>
                    {e.name}
                  </option>
                ))}
            </select>
          )}

          <input
            name="target"
            inputMode="decimal"
            required
            placeholder={TYPE_COPY[type].hint}
            aria-label={TYPE_COPY[type].hint}
            className="h-12 rounded-full border border-ink/15 bg-surface px-5 text-center font-mono outline-none focus:border-blush-deep"
          />

          <label className="flex items-center justify-between gap-3 px-1">
            <span className="text-xs text-ink-soft">Deadline (optional)</span>
            <input
              name="deadline"
              type="date"
              className="h-12 rounded-full border border-ink/15 bg-surface px-4 font-mono text-xs outline-none"
            />
          </label>

          <PillButton type="submit">Set goal</PillButton>
        </form>
      </Sheet>
    </div>
  );
}
