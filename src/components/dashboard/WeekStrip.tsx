import Link from "next/link";
import { Check } from "lucide-react";
import { cn } from "@/lib/cn";

/**
 * Five pills — sage when done, blush ring on the next session.
 * Each pill is a link: train the days in any order you like.
 */
export function WeekStrip({
  days,
}: {
  days: { id: string; index: number; done: boolean; isNext: boolean }[];
}) {
  return (
    <div className="flex items-center justify-between gap-2">
      {days.map((d) => (
        <Link
          key={d.id}
          href={`/workout/${d.id}`}
          aria-label={`Day ${d.index}${d.done ? " — done" : ""}`}
          className={cn(
            "flex h-12 flex-1 items-center justify-center rounded-full border transition-all duration-200",
            "active:scale-[0.96]",
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
        </Link>
      ))}
    </div>
  );
}
