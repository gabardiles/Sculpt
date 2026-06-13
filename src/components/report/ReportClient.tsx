"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  Camera,
  Check,
  Pencil,
  Sparkles,
  TrendingUp,
  Wand2,
} from "lucide-react";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sheet } from "@/components/ui/Sheet";
import { ProgressRing } from "@/components/ui/ProgressRing";
import { DotScale } from "@/components/report/DotScale";
import {
  saveFitnessProfile,
  generateFitnessReport,
  applyWeakPointFocus,
} from "@/lib/actions";
import { formatDay } from "@/lib/format";
import type { FitnessReport } from "@/lib/types";

const METRIC_LABEL: Record<string, string> = {
  conditioning: "Leanness & conditioning",
  core: "Core & midsection",
  upper: "Upper body",
  lower: "Lower body",
  arms: "Arms",
  proportion: "Posture & proportion",
};

const ERROR_COPY: Record<string, string> = {
  not_configured:
    "The report engine isn't switched on yet. Once the app's AI key is set, this works instantly.",
  needs_setup: "Add your details first.",
  needs_photo: "Add a progress photo first — then I can read it.",
  analysis_failed: "Couldn't read that just now. Try again in a moment.",
  save_failed: "Couldn't save the report. Try again.",
};

export function ReportClient({
  needsSetup,
  aiConfigured,
  photoCount,
  hasNewerPhoto,
  latest,
  history,
  profile,
  latestWeight,
}: {
  needsSetup: boolean;
  aiConfigured: boolean;
  photoCount: number;
  hasNewerPhoto: boolean;
  latest: FitnessReport | null;
  history: FitnessReport[];
  profile: {
    gender: "female" | "male" | "unspecified" | null;
    heightCm: number | null;
    goalNote: string | null;
  };
  latestWeight: number | null;
}) {
  const router = useRouter();
  const [setupOpen, setSetupOpen] = useState(false);
  const [setupError, setSetupError] = useState<string | null>(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [applying, setApplying] = useState(false);
  const [applied, setApplied] = useState<string[] | null>(null);

  async function analyze() {
    if (analyzing) return;
    setError(null);
    setAnalyzing(true);
    const res = await generateFitnessReport();
    setAnalyzing(false);
    if (res.ok) {
      setApplied(null);
      router.refresh();
    } else {
      setError(ERROR_COPY[res.error] ?? "Something went wrong.");
    }
  }

  async function applyFocus() {
    if (!latest || applying) return;
    setApplying(true);
    const res = await applyWeakPointFocus(latest.id);
    setApplying(false);
    if (res.ok) setApplied(res.changes);
    else setError(res.error);
  }

  const pastReports = history.filter((r) => r.id !== latest?.id);

  return (
    <main className="animate-fade-in">
      <header className="flex items-start justify-between">
        <div>
          <Eyebrow>FITNESS REPORT</Eyebrow>
          <h1 className="mt-1 text-3xl font-light tracking-wide">Your progress</h1>
        </div>
        {!needsSetup && (
          <button
            aria-label="Edit your details"
            onClick={() => {
              setSetupError(null);
              setSetupOpen(true);
            }}
            className="flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
          >
            <Pencil size={17} strokeWidth={1.5} />
          </button>
        )}
      </header>

      <p className="mt-2 text-sm font-light text-ink-soft">
        A coach&apos;s read of your training photos — scored, honest, kind.
        Guidance, not medical advice.
      </p>

      {!aiConfigured && (
        <Card className="mt-4 border-blush/60 p-4">
          <p className="text-sm font-light leading-relaxed text-ink-soft">
            {ERROR_COPY.not_configured}
          </p>
        </Card>
      )}

      {/* first-run setup prompt */}
      {needsSetup ? (
        <Card className="mt-6 p-6 text-center">
          <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-blush/30 text-blush-deep">
            <Sparkles size={24} strokeWidth={1.6} />
          </span>
          <p className="mt-4 font-light text-lg">Set up your report</p>
          <p className="mt-1 text-sm text-ink-soft">
            A few details so the scoring fits your goal. Takes a moment, edit
            anytime.
          </p>
          <PillButton className="mt-5 w-full" onClick={() => setSetupOpen(true)}>
            Get started
          </PillButton>
        </Card>
      ) : !latest ? (
        // set up, no report yet
        <Card className="mt-6 p-6 text-center">
          <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-blush/30 text-blush-deep">
            <Camera size={24} strokeWidth={1.6} />
          </span>
          {photoCount === 0 ? (
            <>
              <p className="mt-4 font-light text-lg">Add a photo to begin</p>
              <p className="mt-1 text-sm text-ink-soft">
                Your report reads your progress photos. Add one clear, well-lit
                training photo to get your first score.
              </p>
              <Link href="/photos" className="mt-5 block">
                <PillButton className="w-full">Go to Photos</PillButton>
              </Link>
            </>
          ) : (
            <>
              <p className="mt-4 font-light text-lg">Ready for your first report</p>
              <p className="mt-1 text-sm text-ink-soft">
                I&apos;ll read your latest {photoCount === 1 ? "photo" : "photos"}{" "}
                and score where you are.
              </p>
              <PillButton
                className="mt-5 w-full"
                disabled={analyzing || !aiConfigured}
                onClick={analyze}
              >
                <Sparkles size={16} strokeWidth={1.6} />
                {analyzing ? "Analyzing…" : "Analyze my photos"}
              </PillButton>
            </>
          )}
          {error && <p className="mt-3 text-xs text-blush-deep">{error}</p>}
        </Card>
      ) : (
        // the report
        <>
          {analyzing && (
            <p className="mt-4 text-center text-sm text-ink-soft">
              Analyzing your photos…
            </p>
          )}

          {!latest.assessable ? (
            <Card className="mt-6 p-6 text-center">
              <p className="font-light text-lg">Couldn&apos;t read that one</p>
              <p className="mt-2 text-sm font-light leading-relaxed text-ink-soft">
                {latest.summary ||
                  "Add a clear, well-lit photo showing your full physique and try again."}
              </p>
              <PillButton
                className="mt-5 w-full"
                disabled={analyzing || !aiConfigured}
                onClick={analyze}
              >
                <Sparkles size={16} strokeWidth={1.6} /> Try again
              </PillButton>
            </Card>
          ) : (
            <>
              {/* overall score */}
              <Card className="mt-6 p-6">
                <div className="flex items-center gap-5">
                  <ProgressRing progress={latest.overall_score / 10}>
                    <MonoNumber className="text-xl font-light">
                      {latest.overall_score.toFixed(1)}
                    </MonoNumber>
                  </ProgressRing>
                  <div className="min-w-0 flex-1">
                    <Eyebrow>{latest.level ?? "Your level"}</Eyebrow>
                    <p className="mt-0.5 text-2xl font-light tracking-wide">
                      {latest.overall_score.toFixed(1)}
                      <span className="text-base text-ink-soft">/10</span>
                    </p>
                    {latest.next_level && (
                      <MonoNumber className="mt-0.5 block text-[11px] uppercase tracking-wider text-ink-soft">
                        Next: {latest.next_level}
                      </MonoNumber>
                    )}
                  </div>
                </div>
                {latest.summary && (
                  <p className="mt-4 text-sm font-light leading-relaxed text-ink-soft">
                    {latest.summary}
                  </p>
                )}
                <MonoNumber className="mt-3 block text-[11px] uppercase tracking-wider text-ink-soft/70">
                  {formatDay(latest.created_at)} · {latest.photo_count}{" "}
                  {latest.photo_count === 1 ? "photo" : "photos"}
                </MonoNumber>
              </Card>

              {/* the scored lines */}
              <section className="mt-5">
                <Eyebrow>THE BREAKDOWN</Eyebrow>
                <Card className="mt-2 divide-y divide-edge px-5 py-1">
                  {latest.metrics.map((m) => (
                    <DotScale
                      key={m.key}
                      label={METRIC_LABEL[m.key] ?? m.label}
                      score={m.score}
                      comment={m.comment}
                    />
                  ))}
                </Card>
              </section>

              {/* strengths */}
              {latest.strengths.length > 0 && (
                <section className="mt-5">
                  <Eyebrow>STRENGTHS</Eyebrow>
                  <Card className="mt-2 p-4">
                    <ul className="flex flex-col gap-2">
                      {latest.strengths.map((s, i) => (
                        <li key={i} className="flex gap-2 text-sm font-light">
                          <Check
                            size={16}
                            strokeWidth={2}
                            className="mt-0.5 shrink-0 text-sage-deep"
                          />
                          <span>{s}</span>
                        </li>
                      ))}
                    </ul>
                  </Card>
                </section>
              )}

              {/* weak points + next level */}
              {(latest.focus_areas.length > 0 || latest.next_level_advice) && (
                <section className="mt-5">
                  <Eyebrow>WHERE TO PUSH</Eyebrow>
                  <Card className="mt-2 p-4">
                    {latest.focus_areas.length > 0 && (
                      <ul className="flex flex-col gap-2">
                        {latest.focus_areas.map((s, i) => (
                          <li key={i} className="flex gap-2 text-sm font-light">
                            <TrendingUp
                              size={16}
                              strokeWidth={1.6}
                              className="mt-0.5 shrink-0 text-blush-deep"
                            />
                            <span>{s}</span>
                          </li>
                        ))}
                      </ul>
                    )}
                    {latest.next_level_advice && (
                      <p className="mt-3 border-t border-edge pt-3 text-sm font-light leading-relaxed text-ink-soft">
                        <span className="font-medium text-ink">
                          To reach {latest.next_level ?? "the next level"}:{" "}
                        </span>
                        {latest.next_level_advice}
                      </p>
                    )}
                  </Card>
                </section>
              )}

              {/* one-tap weak-point plan */}
              {latest.focus_muscles.length > 0 && (
                <section className="mt-5">
                  {applied ? (
                    <Card className="border-sage/50 p-4">
                      <p className="flex items-center gap-2 text-sm font-medium text-sage-deep">
                        <Check size={16} strokeWidth={2} /> Added to your program
                      </p>
                      <ul className="mt-2 flex flex-col gap-1">
                        {applied.map((c, i) => (
                          <li key={i} className="text-sm font-light text-ink-soft">
                            {c}
                          </li>
                        ))}
                      </ul>
                      <Link href="/program" className="mt-3 block">
                        <PillButton variant="ghost" className="w-full">
                          See my program
                        </PillButton>
                      </Link>
                    </Card>
                  ) : (
                    <Card className="p-4">
                      <p className="text-sm font-light leading-relaxed text-ink-soft">
                        Want your training to chase these weak points? I&apos;ll
                        add targeted accessory work to your program — same big
                        lifts, sharper focus.
                      </p>
                      <PillButton
                        className="mt-3 w-full"
                        disabled={applying}
                        onClick={applyFocus}
                      >
                        <Wand2 size={16} strokeWidth={1.6} />
                        {applying ? "Building…" : "Focus my weak points"}
                      </PillButton>
                    </Card>
                  )}
                </section>
              )}

              {error && (
                <p className="mt-3 text-center text-xs text-blush-deep">{error}</p>
              )}

              {/* re-analyze */}
              <section className="mt-6">
                {hasNewerPhoto && (
                  <p className="mb-2 text-center text-xs text-blush-deep">
                    You&apos;ve added a new photo since this report.
                  </p>
                )}
                <PillButton
                  variant="ghost"
                  className="w-full"
                  disabled={analyzing || !aiConfigured}
                  onClick={analyze}
                >
                  <Sparkles size={16} strokeWidth={1.6} />
                  {analyzing ? "Analyzing…" : "Update my report"}
                </PillButton>
              </section>
            </>
          )}

          {/* score history */}
          {pastReports.length > 0 && (
            <section className="mt-8">
              <Eyebrow>HISTORY</Eyebrow>
              <ul className="mt-2 flex flex-col gap-1.5">
                {pastReports.map((r) => (
                  <li key={r.id}>
                    <MonoNumber className="block text-xs text-ink-soft">
                      {formatDay(r.created_at)} ·{" "}
                      {r.assessable ? `${r.overall_score.toFixed(1)}/10` : "—"}
                      {r.level && r.assessable && <> · {r.level}</>}
                    </MonoNumber>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}

      {/* setup sheet */}
      <Sheet
        open={setupOpen}
        onClose={() => setSetupOpen(false)}
        title="Your details"
      >
        <form
          action={async (fd) => {
            setSetupError(null);
            const res = await saveFitnessProfile(fd);
            if (res.ok) {
              setSetupOpen(false);
              router.refresh();
            } else {
              setSetupError(res.error);
            }
          }}
          className="flex flex-col gap-3 pb-2"
        >
          <div>
            <span className="eyebrow">Your goal aesthetic</span>
            <select
              name="gender"
              required
              defaultValue={profile.gender ?? ""}
              className="mt-1 h-12 w-full rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none"
            >
              <option value="" disabled>
                Pick one
              </option>
              <option value="female">Lean &amp; toned (women&apos;s)</option>
              <option value="male">Athletic &amp; strong (men&apos;s)</option>
              <option value="unspecified">Balanced athletic</option>
            </select>
          </div>
          <div className="flex gap-2">
            <label className="flex-1">
              <span className="eyebrow">Height (cm)</span>
              <input
                name="height_cm"
                type="number"
                inputMode="decimal"
                min="120"
                max="230"
                defaultValue={profile.heightCm ?? ""}
                placeholder="175"
                className="mt-1 h-12 w-full rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none focus:border-blush-deep"
              />
            </label>
            <label className="flex-1">
              <span className="eyebrow">Weight (kg)</span>
              <input
                name="weight"
                type="number"
                inputMode="decimal"
                min="0"
                defaultValue={latestWeight ?? ""}
                placeholder="70"
                className="mt-1 h-12 w-full rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none focus:border-blush-deep"
              />
            </label>
          </div>
          <label>
            <span className="eyebrow">Your dream focus (optional)</span>
            <input
              name="goal_note"
              maxLength={200}
              defaultValue={profile.goalNote ?? ""}
              placeholder="e.g. a visible six-pack"
              className="mt-1 h-12 w-full rounded-full border border-ink/15 bg-surface px-4 text-sm outline-none focus:border-blush-deep"
            />
          </label>
          {setupError && (
            <p className="text-center text-xs text-blush-deep">{setupError}</p>
          )}
          <PillButton type="submit">Save</PillButton>
          <p className="text-center text-xs font-light text-ink-soft">
            Private to you. Weight is shared with your weight diary.
          </p>
        </form>
      </Sheet>
    </main>
  );
}
