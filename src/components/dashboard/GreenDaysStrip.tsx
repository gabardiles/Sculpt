import { Flame } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import {
  type ActivityDay,
  type DayState,
  dayState,
  summarize,
  todayISO,
} from "@/lib/greenDays";

// Compact consistency strip for the Today screen — current streak, the last
// fortnight of green/gold days, and the running points total. The full
// calendar + leaderboard lives in the iOS app (Apple Health steps).
export function GreenDaysStrip({ days }: { days: ActivityDay[] }) {
  const summary = summarize(days);
  const stateByDate = new Map(days.map((d) => [d.date, dayState(d)]));

  const today = new Date(todayISO() + "T00:00:00Z");
  const recent = Array.from({ length: 14 }, (_, i) => {
    const d = new Date(today);
    d.setUTCDate(d.getUTCDate() - (13 - i));
    const key = d.toISOString().slice(0, 10);
    return { key, state: (stateByDate.get(key) ?? "none") as DayState };
  });

  return (
    <section className="mt-6">
      <Eyebrow>GREEN DAYS</Eyebrow>
      <Card className="mt-2 p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Flame
              size={20}
              strokeWidth={1.6}
              className={summary.currentStreak > 0 ? "text-blush-deep" : "text-ink-soft/40"}
            />
            <MonoNumber className="text-2xl font-light">{summary.currentStreak}</MonoNumber>
            <span className="text-[13px] text-ink-soft">day streak</span>
          </div>
          <div className="text-right">
            <MonoNumber className="block text-base">{summary.totalPoints}</MonoNumber>
            <span className="text-[11px] text-ink-soft">{summary.levelName}</span>
          </div>
        </div>
        <div className="mt-3 flex items-center justify-between gap-1">
          {recent.map(({ key, state }) => (
            <span
              key={key}
              title={key}
              className={`h-5 w-5 rounded-[5px] ${
                state === "gold"
                  ? "bg-blush"
                  : state === "green"
                    ? "bg-sage-deep"
                    : "bg-edge/60"
              }`}
            />
          ))}
        </div>
      </Card>
    </section>
  );
}
