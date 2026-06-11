"use client";

import { useEffect, useState } from "react";
import { Timer } from "lucide-react";
import { MonoNumber } from "@/components/ui/MonoNumber";

/** Quiet rest countdown chip. Tap to dismiss. */
export function RestTimer({
  until,
  onDismiss,
}: {
  until: number;
  onDismiss: () => void;
}) {
  const [remaining, setRemaining] = useState(() =>
    Math.max(0, Math.ceil((until - Date.now()) / 1000))
  );

  useEffect(() => {
    const id = setInterval(() => {
      const left = Math.max(0, Math.ceil((until - Date.now()) / 1000));
      setRemaining(left);
      if (left <= 0) {
        clearInterval(id);
        onDismiss();
      }
    }, 250);
    return () => clearInterval(id);
  }, [until, onDismiss]);

  const m = Math.floor(remaining / 60);
  const s = remaining % 60;

  return (
    <button
      onClick={onDismiss}
      className="flex min-h-12 items-center gap-2 rounded-full px-5 text-ink-soft active:scale-[0.98] transition-transform bg-bg/95 backdrop-blur-xl border border-white/70 shadow-[0_8px_32px_rgba(43,36,34,0.12)]"
      aria-label="Dismiss rest timer"
    >
      <Timer size={16} strokeWidth={1.5} />
      <MonoNumber className="text-sm">
        {m}:{String(s).padStart(2, "0")}
      </MonoNumber>
      <span className="text-[10px] uppercase tracking-wider">rest</span>
    </button>
  );
}
