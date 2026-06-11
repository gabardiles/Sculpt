import { requireUser } from "@/lib/data";
import { logBodyWeight } from "@/lib/actions";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sparkline } from "@/components/weight/Sparkline";
import { formatDay, formatKg, todayISO } from "@/lib/format";
import type { BodyWeight } from "@/lib/types";

export default async function WeightPage() {
  const { supabase, user } = await requireUser();
  const since = new Date(Date.now() - 70 * 86_400_000).toISOString().slice(0, 10);
  const { data } = await supabase
    .from("body_weight")
    .select("*")
    .eq("user_id", user.id)
    .gte("date", since)
    .order("date");
  const rows = (data ?? []) as BodyWeight[];

  // Daily fluctuation discourages — the 7-day average is the headline.
  const weekAgo = new Date(Date.now() - 7 * 86_400_000).toISOString().slice(0, 10);
  const lastWeek = rows.filter((r) => r.date >= weekAgo);
  const weeklyAvg = lastWeek.length
    ? lastWeek.reduce((a, r) => a + Number(r.weight_kg), 0) / lastWeek.length
    : null;

  // Weekly averages for the sparkline (last 8 weeks).
  const weeks: number[] = [];
  for (let w = 7; w >= 0; w--) {
    const end = Date.now() - w * 7 * 86_400_000;
    const start = end - 7 * 86_400_000;
    const inWeek = rows.filter((r) => {
      const t = new Date(r.date).getTime();
      return t > start && t <= end;
    });
    if (inWeek.length) {
      weeks.push(inWeek.reduce((a, r) => a + Number(r.weight_kg), 0) / inWeek.length);
    }
  }

  const recent = [...rows].reverse().slice(0, 7);
  const today = todayISO();
  const todayRow = rows.find((r) => r.date === today);

  return (
    <main className="animate-fade-in">
      <Eyebrow>WEIGHT DIARY</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">Body weight</h1>

      <Card className="mt-6 p-6 text-center hero-gradient">
        <Eyebrow>7-DAY AVERAGE</Eyebrow>
        <MonoNumber className="mt-1 block text-5xl font-light">
          {weeklyAvg != null ? formatKg(weeklyAvg) : "—"}
          <span className="ml-1 text-lg text-ink-soft">kg</span>
        </MonoNumber>
        {weeks.length >= 2 && (
          <div className="mt-4 flex justify-center">
            <Sparkline values={weeks} />
          </div>
        )}
      </Card>

      <Card className="mt-4 p-5">
        <form action={logBodyWeight} className="flex items-center gap-3">
          <input type="hidden" name="date" value={today} />
          <input
            name="weight"
            inputMode="decimal"
            required
            placeholder={todayRow ? formatKg(Number(todayRow.weight_kg)) : "62,4"}
            aria-label="Today's weight in kg"
            className="h-12 w-full flex-1 rounded-full border border-ink/15 bg-white/60 px-5 text-center font-mono text-xl outline-none focus:border-blush-deep"
          />
          <PillButton type="submit" className="shrink-0">
            {todayRow ? "Update" : "Log"}
          </PillButton>
        </form>
        {todayRow && (
          <p className="mt-2 text-center text-xs text-ink-soft">
            Logged today: <MonoNumber>{formatKg(Number(todayRow.weight_kg))} kg</MonoNumber>
          </p>
        )}
      </Card>

      {recent.length === 0 ? (
        <p className="mt-10 text-center text-sm font-light text-ink-soft">
          Nothing logged yet — your first entry starts the trend.
        </p>
      ) : (
        <section className="mt-6">
          <Eyebrow>RECENT</Eyebrow>
          <ul className="mt-2 flex flex-col gap-1.5">
            {recent.map((r) => (
              <li key={r.id} className="flex items-baseline justify-between">
                <span className="text-sm font-light text-ink-soft">
                  {formatDay(r.date)}
                </span>
                <MonoNumber className="text-sm">
                  {formatKg(Number(r.weight_kg))} kg
                </MonoNumber>
              </li>
            ))}
          </ul>
        </section>
      )}
    </main>
  );
}
