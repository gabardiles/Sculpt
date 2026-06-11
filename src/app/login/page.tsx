"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow } from "@/components/ui/MonoNumber";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  async function sendLink(e: React.FormEvent) {
    e.preventDefault();
    setState("sending");
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim().toLowerCase(),
      options: {
        // Invite-only: never create accounts from the login screen.
        shouldCreateUser: false,
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) {
      setState("error");
      setError(
        error.message.toLowerCase().includes("signups")
          ? "This app is invite-only. Ask Gabriel for an invite."
          : error.message
      );
    } else {
      setState("sent");
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
          {state === "sent" ? (
            <div className="text-center py-4">
              <p className="font-light text-lg">Check your inbox</p>
              <p className="mt-2 text-sm text-ink-soft">
                A magic link is on its way to{" "}
                <span className="font-mono text-xs">{email}</span>
              </p>
            </div>
          ) : (
            <form onSubmit={sendLink} className="flex flex-col gap-4">
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
              <PillButton type="submit" disabled={state === "sending" || !email}>
                {state === "sending" ? "Sending…" : "Send magic link"}
              </PillButton>
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
