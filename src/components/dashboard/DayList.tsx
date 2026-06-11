import Link from "next/link";
import { Check, ChevronRight } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { MonoNumber } from "@/components/ui/MonoNumber";
import { formatDay } from "@/lib/format";
import { cn } from "@/lib/cn";

export interface DayRowItem {
  id: string;
  index: number;
  name: string;
  done: boolean;
  doneAt: string | null;
  isNext: boolean;
}

/**
 * The week as thin, readable rows — name visible, any order tappable.
 * Done rows go sage with a check; the suggested next one is ringed.
 */
export function DayList({ days }: { days: DayRowItem[] }) {
  return (
    <ul className="flex flex-col gap-2">
      {days.map((d) => (
        <li key={d.id}>
          <Link href={`/workout/${d.id}`}>
            <Card
              done={d.done}
              className={cn(
                "flex items-center gap-3 px-4 py-3 active:scale-[0.99] transition-transform",
                d.isNext && "ring-2 ring-blush-deep/60"
              )}
            >
              <span
                className={cn(
                  "flex h-8 w-8 shrink-0 items-center justify-center rounded-full border",
                  d.done
                    ? "border-sage bg-sage text-white"
                    : "border-ink/15 bg-white/50"
                )}
              >
                {d.done ? (
                  <Check size={15} strokeWidth={2.2} />
                ) : (
                  <MonoNumber className="text-xs text-ink-soft">
                    {d.index}
                  </MonoNumber>
                )}
              </span>
              <span className="min-w-0 flex-1">
                <span
                  className={cn(
                    "block truncate",
                    d.done ? "text-sage-deep" : "text-ink",
                    d.isNext ? "font-medium" : "font-light"
                  )}
                >
                  Day {d.index} · {d.name}
                </span>
              </span>
              {d.done && d.doneAt ? (
                <MonoNumber className="shrink-0 text-xs text-sage-deep">
                  {formatDay(d.doneAt)}
                </MonoNumber>
              ) : (
                <ChevronRight
                  size={17}
                  strokeWidth={1.5}
                  className="shrink-0 text-ink-soft"
                />
              )}
            </Card>
          </Link>
        </li>
      ))}
    </ul>
  );
}
