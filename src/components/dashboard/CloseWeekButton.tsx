"use client";

import { useState } from "react";
import { Check } from "lucide-react";
import { PillButton } from "@/components/ui/PillButton";
import { closeWeek } from "@/lib/actions";
import type { WeekIntensity } from "@/lib/types";

/** Appears from 3/5 sessions: close the week and move to the next one.
 *  Fixed-schedule programs pass week_index as cycle, intensity as phase. */
export function CloseWeekButton({
  cycle,
  phase,
  doneCount,
  totalCount = 5,
  skippedNames,
}: {
  cycle: number;
  phase: WeekIntensity;
  doneCount: number;
  totalCount?: number;
  skippedNames: string[];
}) {
  const [busy, setBusy] = useState(false);

  return (
    <div className="mt-3 flex flex-col items-center gap-1.5">
      <PillButton
        variant="ghost"
        disabled={busy}
        onClick={async () => {
          setBusy(true);
          await closeWeek(cycle, phase);
          setBusy(false);
        }}
      >
        <Check size={16} strokeWidth={1.8} />
        {busy ? "Closing…" : `Finish week (${doneCount}/${totalCount})`}
      </PillButton>
      <p className="px-4 text-center text-xs text-ink-soft">
        3 of {totalCount} is a full week. All {totalCount} earns the star.
        {skippedNames.length > 0 && (
          <>
            {" "}
            Skipping {skippedNames.join(" & ")} — they&apos;ll come first next
            week.
          </>
        )}
      </p>
    </div>
  );
}
