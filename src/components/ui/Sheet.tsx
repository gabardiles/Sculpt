"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { X } from "lucide-react";
import { cn } from "@/lib/cn";

/** Bottom sheet — used for instruction videos, swaps, feel rating. */
export function Sheet({
  open,
  onClose,
  title,
  children,
  className,
}: {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  className?: string;
}) {
  // Portal target — only available after mount.
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [open, onClose]);

  if (!open || !mounted) return null;

  // Portaled to <body>: an animated/transformed ancestor would otherwise
  // become the containing block for this fixed overlay and push the panel
  // off-screen.
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-end justify-center">
      <button
        aria-label="Close"
        className="absolute inset-0 bg-ink/20 backdrop-blur-[2px] animate-fade-up"
        onClick={onClose}
      />
      <div
        role="dialog"
        aria-modal="true"
        className={cn(
          "relative w-full max-w-md max-h-[88dvh] overflow-y-auto",
          "rounded-t-[28px] bg-bg/95 backdrop-blur-xl border-t border-edge",
          "px-5 pt-3 pb-[max(1.25rem,env(safe-area-inset-bottom))] animate-fade-up",
          className
        )}
      >
        <div className="mx-auto mb-3 h-1 w-10 rounded-full bg-ink/10" />
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-light tracking-wide">{title}</h2>
          <button
            onClick={onClose}
            aria-label="Close sheet"
            className="flex h-12 w-12 items-center justify-center rounded-full text-ink-soft active:bg-ink/5"
          >
            <X size={20} strokeWidth={1.5} />
          </button>
        </div>
        {children}
      </div>
    </div>,
    document.body
  );
}
