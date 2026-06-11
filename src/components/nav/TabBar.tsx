"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, CalendarRange, Heart, CircleUser } from "lucide-react";
import { cn } from "@/lib/cn";

const TABS = [
  { href: "/", label: "Today", icon: Home, match: ["/", "/workout"] },
  { href: "/program", label: "Program", icon: CalendarRange, match: ["/program"] },
  { href: "/friends", label: "Friends", icon: Heart, match: ["/friends"] },
  {
    href: "/you",
    label: "You",
    icon: CircleUser,
    match: ["/you", "/weight", "/photos", "/goals"],
  },
];

export function TabBar() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 inset-x-0 z-40">
      <div className="mx-auto max-w-md px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
        {/* Near-opaque so scrolling content doesn't bleed through the bar */}
        <div className="flex items-stretch justify-between rounded-full px-2 bg-bg/95 backdrop-blur-xl border border-white/70 shadow-[0_8px_32px_rgba(43,36,34,0.10)]">
          {TABS.map(({ href, label, icon: Icon, match }) => {
            const active = match.some((m) =>
              m === "/" ? pathname === "/" : pathname.startsWith(m)
            );
            return (
              <Link
                key={href}
                href={href}
                className={cn(
                  "flex min-w-12 min-h-14 flex-1 flex-col items-center justify-center gap-0.5 rounded-full",
                  "transition-colors duration-150",
                  active ? "text-ink" : "text-ink-soft/70"
                )}
              >
                <Icon size={20} strokeWidth={active ? 1.8 : 1.4} />
                <span
                  className={cn(
                    "text-[11px] tracking-wide",
                    active ? "font-medium" : "font-light"
                  )}
                >
                  {label}
                </span>
              </Link>
            );
          })}
        </div>
      </div>
    </nav>
  );
}
