"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow } from "@/components/ui/MonoNumber";

type Step = "email" | "code";

export default function LoginPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim().toLowerCase(),
      options: {
        // Invite-only: never create accounts from the login screen.
        shouldCreateUser: false,
      },
    });
    if (error) {
      setError(
        error.message.toLowerCase().includes("signup")
          ? "This app is invite-only. Ask Gabriel for an invite."
          : error.message
      );
    } else {
      setStep("code");
    }
    setBusy(false);
  }

  async function verifyCode(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.verifyOtp({
      email: email.trim().toLowerCase(),
      token: code.trim(),
      type: "email",
    });
    if (error) {
      setError("That code didn't work. Check the digits and try again.");
      setBusy(false);
    } else {
      router.replace("/");
      router.refresh();
    }
  }

  return (
    <main className="min-h-dvh hero-gradient flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-sm animate-fade-up">
        <div className="text-center mb-10">
          <Eyebrow>TRAINING TRACKER</Eyebrow>
          <h1 className="mt-2 text-4xl font-light tracking-widest uppercase">
            Sculpt
          </h1>
        </div>

        <Card className="p-6">
          {step === "email" ? (
            <form onSubmit={sendCode} className="flex flex-col gap-4">
              <label className="eyebrow" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                type="email"
                required
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                className="h-12 rounded-full border border-ink/15 bg-white/60 px-5 text-base outline-none focus:border-blush-deep"
              />
              {error && <p className="text-sm text-blush-deep">{error}</p>}
              <PillButton type="submit" disabled={busy || !email}>
                {busy ? "Sending…" : "Email me a code"}
              </PillButton>
            </form>
          ) : (
            <form onSubmit={verifyCode} className="flex flex-col gap-4">
              <div className="text-center">
                <p className="font-light">Check your inbox</p>
                <p className="mt-1 text-xs text-ink-soft">
                  We sent a 6-digit code to{" "}
                  <span className="font-mono">{email}</span>
                </p>
              </div>
              <input
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={10}
                required
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                placeholder="········"
                aria-label="Sign-in code"
                className="h-14 rounded-full border border-ink/15 bg-white/60 px-5 text-center font-mono text-2xl tracking-[0.3em] outline-none focus:border-blush-deep"
              />
              {error && (
                <p className="text-center text-sm text-blush-deep">{error}</p>
              )}
              <PillButton type="submit" disabled={busy || code.length < 6}>
                {busy ? "Checking…" : "Sign in"}
              </PillButton>
              <button
                type="button"
                onClick={() => {
                  setStep("email");
                  setCode("");
                  setError(null);
                }}
                className="min-h-10 text-center text-xs text-ink-soft underline-offset-2 active:underline"
              >
                Use a different email
              </button>
            </form>
          )}
        </Card>

        <p className="mt-6 text-center text-xs text-ink-soft">
          Invite-only. No passwords, ever.
        </p>
      </div>
    </main>
  );
}
