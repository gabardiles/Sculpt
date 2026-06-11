import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { ProgressRing } from "@/components/ui/ProgressRing";
import { Check } from "lucide-react";

const TOKENS = [
  { name: "--bg", value: "#FBF7F6", cls: "bg-bg border" },
  { name: "--blush", value: "#E8C8C4", cls: "bg-blush" },
  { name: "--blush-deep", value: "#C9938E", cls: "bg-blush-deep" },
  { name: "--ink", value: "#2B2422", cls: "bg-ink" },
  { name: "--ink-soft", value: "#8A7E7A", cls: "bg-ink-soft" },
  { name: "--sage", value: "#A9BCA4", cls: "bg-sage" },
];

export default function StyleguidePage() {
  return (
    <main className="mx-auto max-w-md px-5 py-10 hero-gradient min-h-dvh">
      <Eyebrow>STYLEGUIDE</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">Sculpt</h1>

      <section className="mt-8">
        <Eyebrow>COLOR</Eyebrow>
        <div className="mt-2 grid grid-cols-3 gap-2">
          {TOKENS.map((t) => (
            <div key={t.name}>
              <div className={`h-14 rounded-2xl ${t.cls} border-ink/10`} />
              <MonoNumber className="mt-1 block text-[11px] text-ink-soft">
                {t.name}
              </MonoNumber>
            </div>
          ))}
        </div>
      </section>

      <section className="mt-8">
        <Eyebrow>TYPE</Eyebrow>
        <h2 className="mt-2 text-3xl font-light tracking-wide">
          Heading — Geist 300
        </h2>
        <p className="mt-1 font-normal">Body — Geist 400</p>
        <p className="mt-1 font-medium">Emphasis — Geist 500, never 600+</p>
        <MonoNumber className="mt-2 block text-2xl font-light">
          42,5 kg · 6–8 · 3×
        </MonoNumber>
      </section>

      <section className="mt-8">
        <Eyebrow>SURFACES</Eyebrow>
        <Card className="mt-2 p-5">
          <Eyebrow>NEXT UP · DAY 1</Eyebrow>
          <p className="mt-1 text-xl font-light tracking-wide">
            Glutes &amp; Hamstrings
          </p>
          <MonoNumber className="mt-2 block text-xs text-ink-soft">
            6 exercises · 10–12 reps · 3 sets
          </MonoNumber>
        </Card>
        <Card done className="mt-3 flex items-center gap-3 p-5">
          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-sage text-white">
            <Check size={14} strokeWidth={2.5} />
          </span>
          <p className="font-light">Completed card — sage, never neon</p>
        </Card>
      </section>

      <section className="mt-8">
        <Eyebrow>BUTTONS</Eyebrow>
        <div className="mt-2 flex flex-wrap gap-3">
          <PillButton>Primary</PillButton>
          <PillButton variant="ghost">Ghost</PillButton>
          <PillButton variant="sage">
            <Check size={16} strokeWidth={2} /> Done
          </PillButton>
        </div>
      </section>

      <section className="mt-8">
        <Eyebrow>PROGRESS</Eyebrow>
        <div className="mt-2 flex items-center gap-6">
          <ProgressRing progress={0.66}>
            <MonoNumber className="text-[11px] text-ink-soft">66%</MonoNumber>
          </ProgressRing>
          <ProgressRing progress={1} done>
            <MonoNumber className="text-[11px] text-sage-deep">✓</MonoNumber>
          </ProgressRing>
          <div className="flex flex-1 items-center gap-2">
            {[1, 1, 1, 0, 0].map((done, i) => (
              <div
                key={i}
                className={`flex h-12 flex-1 items-center justify-center rounded-full border ${
                  done
                    ? "bg-sage/40 border-sage/50 text-sage-deep"
                    : "bg-surface-soft border-edge text-ink-soft"
                } ${i === 3 ? "ring-2 ring-blush-deep/60 ring-offset-2 ring-offset-bg" : ""}`}
              >
                {done ? (
                  <Check size={14} strokeWidth={2} />
                ) : (
                  <MonoNumber className="text-xs">D{i + 1}</MonoNumber>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
