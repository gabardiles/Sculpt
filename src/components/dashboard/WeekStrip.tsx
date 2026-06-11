import { Check } from "lucide-react";
import { cn } from "@/lib/cn";

/** Five pills — sage when done, blush ring on the next session. */
export function WeekStrip({
  days,
}: {
  days: { id: string; index: number; done: boolean; isNext: boolean }[];
}) {
  return (
    <div className="flex items-center justify-between gap-2">
      {days.map((d) => (
        <div
          key={d.id}
          className={cn(
            "flex h-12 flex-1 items-center justify-center rounded-full border transition-colors duration-200",
            d.done
              ? "bg-sage/40 border-sage/50 text-sage-deep"
              : "bg-white/40 border-white/60 text-ink-soft",
            d.isNext && "ring-2 ring-blush-deep/60 ring-offset-2 ring-offset-bg"
          )}
        >
          {d.done ? (
            <Check size={16} strokeWidth={2} />
          ) : (
            <span className="font-mono text-xs">D{d.index}</span>
          )}
        </div>
      ))}
    </div>
  );
}
