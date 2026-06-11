"use client";

import { useEffect } from "react";

/**
 * Mirrors the theme onto <html> so portaled UI (sheets, toasts) and the
 * body background pick up the variables. The SSR wrapper div already
 * carries data-theme for a correct first paint — this runs post-hydration
 * and costs nothing.
 */
export function ThemeSync({ theme }: { theme: string }) {
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    return () => {
      delete document.documentElement.dataset.theme;
    };
  }, [theme]);
  return null;
}
