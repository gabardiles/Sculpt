import Link from "next/link";
import { Camera, ChevronRight, Target, TrendingUp } from "lucide-react";
import { requireUser, getProfile, getGoals } from "@/lib/data";
import { Card } from "@/components/ui/Card";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { formatKg } from "@/lib/format";

export default async function YouPage() {
  const { supabase, user } = await requireUser();

  const weekAgo = new Date(Date.now() - 7 * 86_400_000)
    .toISOString()
    .slice(0, 10);
  const [profile, goals, { data: bw }, { count: photoCount }] =
    await Promise.all([
      getProfile(supabase, user.id),
      getGoals(supabase, user.id),
      supabase
        .from("body_weight")
        .select("weight_kg")
        .eq("user_id", user.id)
        .gte("date", weekAgo),
      supabase
        .from("progress_photos")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id),
    ]);

  const weights = ((bw ?? []) as { weight_kg: number }[]).map((r) =>
    Number(r.weight_kg)
  );
  const weeklyAvg = weights.length
    ? weights.reduce((a, b) => a + b, 0) / weights.length
    : null;
  const activeGoals = goals.filter((g) => !g.achieved).length;

  const sections = [
    {
      href: "/weight",
      icon: TrendingUp,
      title: "Weight diary",
      detail:
        weeklyAvg != null ? `${formatKg(weeklyAvg)} kg · 7-day avg` : "Nothing logged yet",
    },
    {
      href: "/photos",
      icon: Camera,
      title: "Progress photos",
      detail: photoCount ? `${photoCount} photos` : "Week one starts the story",
    },
    {
      href: "/goals",
      icon: Target,
      title: "Goals",
      detail: activeGoals
        ? `${activeGoals} active`
        : "Pick one thing worth chasing",
    },
  ];

  return (
    <main className="animate-fade-up">
      <Eyebrow>YOU</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">
        {profile?.name ?? "Your space"}
      </h1>
      <MonoNumber className="mt-1 block text-[11px] uppercase tracking-[0.14em] text-ink-soft">
        FRIEND CODE · {profile?.friend_code}
      </MonoNumber>

      <div className="mt-6 flex flex-col gap-3">
        {sections.map(({ href, icon: Icon, title, detail }) => (
          <Link key={href} href={href}>
            <Card className="flex items-center gap-4 px-5 py-4 active:scale-[0.99] transition-transform">
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-blush/30 text-ink">
                <Icon size={19} strokeWidth={1.5} />
              </span>
              <span className="flex-1">
                <span className="block font-normal">{title}</span>
                <MonoNumber className="text-xs text-ink-soft">{detail}</MonoNumber>
              </span>
              <ChevronRight size={18} strokeWidth={1.5} className="text-ink-soft" />
            </Card>
          </Link>
        ))}
      </div>
    </main>
  );
}
