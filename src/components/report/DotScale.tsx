import { MonoNumber } from "@/components/ui/MonoNumber";
import { cn } from "@/lib/cn";

/**
 * A 0–10 score as a row of ten dots: dots up to the score fill with the
 * accent, the score's own dot is ringed, and the value sits at the end.
 */
export function DotScale({
  label,
  score,
  comment,
}: {
  label: string;
  score: number;
  comment?: string;
}) {
  const filled = Math.round(score);
  return (
    <div className="py-2.5">
      <div className="flex items-baseline justify-between gap-3">
        <span className="text-sm font-normal">{label}</span>
        <MonoNumber className="shrink-0 text-xs text-ink-soft">
          {score.toFixed(1)}
          <span className="text-ink-soft/60">/10</span>
        </MonoNumber>
      </div>
      <div className="mt-1.5 flex items-center gap-[3px]" aria-hidden>
        {Array.from({ length: 10 }, (_, i) => {
          const n = i + 1;
          const on = n <= filled;
          const isScore = n === filled;
          return (
            <span
              key={n}
              className={cn(
                "h-2 flex-1 rounded-full transition-colors",
                on ? "bg-blush-deep" : "bg-ink/12",
                isScore && "ring-2 ring-blush-deep/40"
              )}
            />
          );
        })}
      </div>
      {comment && (
        <p className="mt-1.5 text-xs font-light leading-relaxed text-ink-soft">
          {comment}
        </p>
      )}
    </div>
  );
}
