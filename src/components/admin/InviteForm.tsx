"use client";

import { useState } from "react";
import { Check, Copy } from "lucide-react";
import { inviteUser } from "@/lib/actions";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow } from "@/components/ui/MonoNumber";

type Result =
  | { state: "error"; message: string }
  | { state: "created"; email: string; emailSent: boolean };

export function InviteForm() {
  const [result, setResult] = useState<Result | null>(null);
  const [busy, setBusy] = useState(false);
  const [copied, setCopied] = useState(false);

  const inviteText = (email: string) =>
    `You're invited to Sculpt 🤍\n\n` +
    `1. Open ${window.location.origin}\n` +
    `2. Sign in with ${email} — a 6-digit code lands in your inbox\n` +
    `3. That's it. No password, ever.\n\n` +
    `Tip: install it like an app — You → Install on your phone.`;

  async function copyInvite(email: string) {
    try {
      await navigator.clipboard.writeText(inviteText(email));
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard unavailable — the text is visible to select manually.
    }
  }

  return (
    <Card className="mt-6 p-6">
      <form
        action={async (fd) => {
          setBusy(true);
          setResult(null);
          const email = String(fd.get("email") ?? "").trim().toLowerCase();
          const res = await inviteUser(fd);
          setResult(
            res?.ok
              ? { state: "created", email, emailSent: res.emailSent ?? false }
              : {
                  state: "error",
                  message: res?.error ?? "Something went wrong.",
                }
          );
          setBusy(false);
        }}
        className="flex flex-col gap-4"
      >
        <input
          name="email"
          type="email"
          required
          placeholder="her@email.com"
          className="h-12 rounded-full border border-ink/15 bg-surface px-5 text-base outline-none focus:border-blush-deep"
        />
        <PillButton type="submit" disabled={busy}>
          {busy ? "Inviting…" : "Invite"}
        </PillButton>

        {result?.state === "error" && (
          <p className="text-center text-sm text-blush-deep">
            {result.message}
          </p>
        )}

        {result?.state === "created" && (
          <div className="rounded-2xl bg-surface p-4">
            <p className="flex items-center gap-1.5 text-sm font-medium text-sage-deep">
              <Check size={15} strokeWidth={2} /> Account created
              {result.emailSent && <> — invite email sent</>}
            </p>
            <p className="mt-1.5 text-sm font-light leading-relaxed text-ink-soft">
              {result.emailSent
                ? "She got the steps by email. You can also send them yourself:"
                : "No email goes out automatically — send her this:"}
            </p>
            <p className="mt-2 whitespace-pre-line rounded-xl bg-surface-soft p-3 text-xs font-light leading-relaxed">
              {inviteText(result.email)}
            </p>
            <PillButton
              variant="ghost"
              className="mt-3 w-full"
              onClick={() => copyInvite(result.email)}
            >
              {copied ? (
                <>
                  <Check size={15} strokeWidth={2} /> Copied
                </>
              ) : (
                <>
                  <Copy size={15} strokeWidth={1.5} /> Copy invite message
                </>
              )}
            </PillButton>
          </div>
        )}
      </form>

      <p className="mt-4 text-xs font-light leading-relaxed text-ink-soft">
        <Eyebrow>HOW IT WORKS</Eyebrow>
        <span className="mt-1 block">
          Inviting creates the account instantly — she signs in with her email
          and a 6-digit code, no link needed.
        </span>
      </p>
    </Card>
  );
}
