"use client";

import { useState } from "react";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";

export interface IntakeValues {
  glutes: number;
  strong: number;
  lean: number;
}

export const INTAKE_DEFAULTS: IntakeValues = { glutes: 5, strong: 3, lean: 3 };

const QUESTIONS: { key: keyof IntakeValues; label: string }[] = [
  { key: "glutes", label: "Glutes & lower body" },
  { key: "strong", label: "Strong — lift heavier" },
  { key: "lean", label: "Lean & toned upper body" },
];

/**
 * Three 1–5 sliders. Uncontrolled-friendly: renders hidden-named inputs for
 * form posts, or reports changes for action calls. Defaults = the audited
 * glute program, untouched.
 */
export function IntakeSliders({
  values,
  onChange,
  withFormNames = false,
}: {
  values?: IntakeValues;
  onChange?: (v: IntakeValues) => void;
  withFormNames?: boolean;
}) {
  const [local, setLocal] = useState<IntakeValues>(values ?? INTAKE_DEFAULTS);

  function set(key: keyof IntakeValues, value: number) {
    const next = { ...local, [key]: value };
    setLocal(next);
    onChange?.(next);
  }

  return (
    <div className="flex flex-col gap-4">
      {QUESTIONS.map(({ key, label }) => (
        <label key={key} className="block">
          <span className="flex items-baseline justify-between">
            <Eyebrow>{label}</Eyebrow>
            <MonoNumber className="text-sm font-medium text-blush-deep">
              {local[key]}
            </MonoNumber>
          </span>
          <input
            type="range"
            min={1}
            max={5}
            step={1}
            value={local[key]}
            name={withFormNames ? key : undefined}
            onChange={(e) => set(key, parseInt(e.target.value, 10))}
            className="mt-1.5 h-2 w-full cursor-pointer appearance-none rounded-full bg-surface-soft accent-[var(--color-blush-deep)]"
            aria-label={`${label}, 1 to 5`}
          />
        </label>
      ))}
    </div>
  );
}
