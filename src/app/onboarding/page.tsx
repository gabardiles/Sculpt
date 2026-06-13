import { redirect } from "next/navigation";
import { requireUser, getProfile, getActiveProgram } from "@/lib/data";
import { completeOnboarding } from "@/lib/actions";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow } from "@/components/ui/MonoNumber";

export default async function OnboardingPage() {
  const { supabase, user } = await requireUser();
  const [profile, program] = await Promise.all([
    getProfile(supabase, user.id),
    getActiveProgram(supabase, user.id),
  ]);

  if (profile?.name && program) redirect("/");

  return (
    <main className="min-h-dvh hero-gradient flex flex-col items-center justify-center px-6 py-10">
      <div className="w-full max-w-sm animate-fade-up">
        <div className="text-center mb-8">
          <Eyebrow>WELCOME</Eyebrow>
          <h1 className="mt-2 text-3xl font-light tracking-wide">
            Let&apos;s get you set up
          </h1>
          <p className="mt-3 text-sm text-ink-soft">
            A few quick details — we&apos;ll suggest a program and a look that
            fit you. You can change anything later.
          </p>
        </div>

        <Card className="p-6">
          <form action={completeOnboarding} className="flex flex-col gap-4">
            <label className="flex flex-col gap-2">
              <span className="eyebrow">Your name</span>
              <input
                name="name"
                type="text"
                required
                autoComplete="given-name"
                placeholder="Alex"
                className="h-12 rounded-full border border-ink/15 bg-surface px-5 text-base outline-none focus:border-blush-deep"
              />
            </label>

            <div className="flex flex-col gap-2">
              <span className="eyebrow">You train as</span>
              <select
                name="sex"
                required
                defaultValue=""
                className="h-12 rounded-full border border-ink/15 bg-surface px-4 text-base outline-none focus:border-blush-deep"
              >
                <option value="" disabled>
                  Choose one
                </option>
                <option value="female">Woman — lean &amp; toned</option>
                <option value="male">Man — athletic &amp; strong</option>
                <option value="unspecified">Prefer not to say</option>
              </select>
              <span className="px-1 text-xs font-light text-ink-soft">
                Sets your suggested program and theme — switch either later.
              </span>
            </div>

            <div className="flex gap-2">
              <label className="flex flex-1 flex-col gap-2">
                <span className="eyebrow">Age</span>
                <input
                  name="age"
                  type="number"
                  inputMode="numeric"
                  min="13"
                  max="100"
                  placeholder="28"
                  className="h-12 rounded-full border border-ink/15 bg-surface px-4 text-base outline-none focus:border-blush-deep"
                />
              </label>
              <label className="flex flex-1 flex-col gap-2">
                <span className="eyebrow">Height (cm)</span>
                <input
                  name="height_cm"
                  type="number"
                  inputMode="decimal"
                  min="120"
                  max="230"
                  placeholder="175"
                  className="h-12 rounded-full border border-ink/15 bg-surface px-4 text-base outline-none focus:border-blush-deep"
                />
              </label>
              <label className="flex flex-1 flex-col gap-2">
                <span className="eyebrow">Weight</span>
                <input
                  name="weight"
                  type="number"
                  inputMode="decimal"
                  min="0"
                  placeholder="70"
                  className="h-12 rounded-full border border-ink/15 bg-surface px-4 text-base outline-none focus:border-blush-deep"
                />
              </label>
            </div>

            <PillButton type="submit" className="mt-1">
              Build my program
            </PillButton>
          </form>
        </Card>
      </div>
    </main>
  );
}
