import Link from "next/link";
import { Check, ChevronRight } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { MonoNumber } from "@/components/ui/MonoNumber";
import { formatDay } from "@/lib/format";
import { dayImage } from "@/lib/editorial";
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
              <span className="relative h-12 w-12 shrink-0 overflow-hidden rounded-xl">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={dayImage(d.index)}
                  alt=""
                  className="absolute inset-0 h-full w-full object-cover"
                />
                {d.done && (
                  <span className="absolute inset-0 flex items-center justify-center bg-sage/75 text-white">
                    <Check size={18} strokeWidth={2.4} />
                  </span>
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
