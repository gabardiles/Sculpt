"use client";

import { useState } from "react";
import { setTheme } from "@/lib/actions";
import { cn } from "@/lib/cn";

const OPTIONS = [
  { value: "sculpt" as const, label: "Sculpt" },
  { value: "spartan" as const, label: "Spartan" },
];

/** Appearance only — switching the look never touches training data. */
export function ThemeSwitch({ current }: { current: "sculpt" | "spartan" }) {
  const [busy, setBusy] = useState(false);
  const [active, setActive] = useState(current);

  return (
    <div className="flex gap-2">
      {OPTIONS.map((o) => (
        <button
          key={o.value}
          disabled={busy}
          onClick={async () => {
            if (o.value === active || busy) return;
            setBusy(true);
            setActive(o.value);
            await setTheme(o.value);
            setBusy(false);
          }}
          className={cn(
            "flex-1 rounded-full border px-4 py-3 text-sm transition-colors min-h-12",
            o.value === active
              ? "border-blush-deep bg-blush/40 font-medium"
              : "border-ink/10 bg-surface-soft font-light text-ink-soft"
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
