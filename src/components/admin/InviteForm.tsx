"use client";

import { useState } from "react";
import { inviteUser } from "@/lib/actions";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";

export function InviteForm() {
  const [status, setStatus] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  return (
    <Card className="mt-6 p-6">
      <form
        action={async (fd) => {
          setBusy(true);
          setStatus(null);
          const res = await inviteUser(fd);
          setStatus(
            res?.ok
              ? res.message ?? "Invite sent ✓"
              : res?.error ?? "Something went wrong."
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
          {busy ? "Sending…" : "Send invite"}
        </PillButton>
        {status && (
          <p className="text-center text-sm text-ink-soft">{status}</p>
        )}
      </form>
    </Card>
  );
}
