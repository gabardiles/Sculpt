import { redirect } from "next/navigation";
import { requireUser, getProfile, getActiveProgram } from "@/lib/data";
import { completeOnboarding } from "@/lib/actions";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow } from "@/components/ui/MonoNumber";
import { IntakeSliders } from "@/components/onboarding/IntakeSliders";

export default async function OnboardingPage() {
  const { supabase, user } = await requireUser();
  const [profile, program] = await Promise.all([
    getProfile(supabase, user.id),
    getActiveProgram(supabase, user.id),
  ]);

  if (profile?.name && program) redirect("/");

  return (
    <main className="min-h-dvh hero-gradient flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-sm animate-fade-up">
        <div className="text-center mb-8">
          <Eyebrow>WELCOME</Eyebrow>
          <h1 className="mt-2 text-3xl font-light tracking-wide">
            Let&apos;s get you set up
          </h1>
          <p className="mt-3 text-sm text-ink-soft">
            Your program: <span className="font-normal text-ink">Lean &amp; Sculpted</span>{" "}
            — 5 days, 3-week cycles. Light, medium, hard. Repeat.
          </p>
        </div>

        <Card className="p-6">
          <form action={completeOnboarding} className="flex flex-col gap-5">
            <div className="flex flex-col gap-2">
              <label className="eyebrow" htmlFor="name">
                Your name
              </label>
              <input
                id="name"
                name="name"
                type="text"
                required
                autoComplete="given-name"
                placeholder="Linnea"
                className="h-12 rounded-full border border-ink/15 bg-surface px-5 text-base outline-none focus:border-blush-deep"
              />
            </div>

            <div>
              <p className="mb-3 text-sm font-light text-ink-soft">
                What matters most to you? The program adjusts — gently.
              </p>
              <IntakeSliders withFormNames />
            </div>

            <PillButton type="submit">Start the cycle</PillButton>
          </form>
        </Card>
      </div>
    </main>
  );
}
