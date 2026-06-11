import Link from "next/link";
import { ArrowLeft, Share, SquarePlus, Smartphone } from "lucide-react";
import { Card } from "@/components/ui/Card";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";

const IOS_STEPS = [
  {
    icon: Smartphone,
    text: "Open Sculpt in Safari (this works from Safari, not from inside another app's browser).",
  },
  {
    icon: Share,
    text: "Tap the Share button — the square with the arrow pointing up, at the bottom of the screen.",
  },
  {
    icon: SquarePlus,
    text: "Scroll down and tap “Add to Home Screen”, then tap Add.",
  },
];

export default function InstallPage() {
  return (
    <main className="animate-fade-in">
      <Link
        href="/you"
        aria-label="Back"
        className="-ml-2 flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
      >
        <ArrowLeft size={20} strokeWidth={1.5} />
      </Link>
      <Eyebrow>GET THE APP FEELING</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">
        Install on iPhone
      </h1>
      <p className="mt-3 text-sm font-light leading-relaxed text-ink-soft">
        Sculpt installs straight from the browser — no App Store. You get the
        heart icon on your home screen, full screen with no address bar, and
        it opens like any other app.
      </p>

      <ol className="mt-6 flex flex-col gap-3">
        {IOS_STEPS.map(({ icon: Icon, text }, i) => (
          <li key={i}>
            <Card className="flex items-center gap-4 p-5">
              <MonoNumber className="text-2xl font-light text-blush-deep">
                {i + 1}
              </MonoNumber>
              <p className="flex-1 text-sm font-light leading-relaxed">
                {text}
              </p>
              <Icon size={22} strokeWidth={1.5} className="shrink-0 text-ink-soft" />
            </Card>
          </li>
        ))}
      </ol>

      <Card className="mt-6 p-5">
        <Eyebrow>ANDROID</Eyebrow>
        <p className="mt-1.5 text-sm font-light leading-relaxed text-ink-soft">
          Open Sculpt in Chrome, tap the ⋮ menu top-right, then
          “Add to Home screen” (sometimes shown as “Install app”).
        </p>
      </Card>

      <p className="mt-6 text-center text-xs text-ink-soft">
        Tip: once installed, sign in once — the session keeps you logged in.
      </p>
    </main>
  );
}
