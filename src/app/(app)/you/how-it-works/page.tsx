import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { Eyebrow } from "@/components/ui/MonoNumber";
import { DAY_RATIONALE, HOW_IT_WORKS, WHY_SWAPS } from "@/lib/programCopy";

export default function HowItWorksPage() {
  return (
    <main className="animate-fade-in">
      <Link
        href="/you"
        aria-label="Back"
        className="-ml-2 flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
      >
        <ArrowLeft size={20} strokeWidth={1.5} />
      </Link>
      <Eyebrow>THE METHOD</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">
        How Sculpt works
      </h1>
      <p className="mt-3 text-sm font-light leading-relaxed text-ink-soft">
        Nothing here is random. The program was designed and audited by the
        training intelligence behind this app, against current evidence on
        how muscle is actually built.
      </p>

      <div className="mt-6 flex flex-col gap-3">
        {HOW_IT_WORKS.map((s) => (
          <Card key={s.title} className="p-5">
            <h2 className="font-normal">{s.title}</h2>
            <p className="mt-1.5 text-sm font-light leading-relaxed text-ink-soft">
              {s.body}
            </p>
          </Card>
        ))}
      </div>

      <section className="mt-8">
        <Eyebrow>EACH DAY, EXPLAINED</Eyebrow>
        <div className="mt-2 flex flex-col gap-3">
          {Object.entries(DAY_RATIONALE).map(([dayName, text]) => (
            <Card key={dayName} className="p-5">
              <h2 className="font-normal">{dayName}</h2>
              <p className="mt-1.5 text-sm font-light leading-relaxed text-ink-soft">
                {text}
              </p>
            </Card>
          ))}
        </div>
      </section>

      <section className="mt-8">
        <Eyebrow>SWAPPING EXERCISES</Eyebrow>
        <Card className="mt-2 p-5">
          <p className="text-sm font-light leading-relaxed text-ink-soft">
            {WHY_SWAPS}
          </p>
        </Card>
      </section>
    </main>
  );
}
