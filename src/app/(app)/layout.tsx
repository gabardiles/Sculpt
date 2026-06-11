import { cookies } from "next/headers";
import { TabBar } from "@/components/nav/TabBar";
import { CheerListener } from "@/components/live/CheerListener";
import { ThemeSync } from "@/components/live/ThemeSync";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  // Cookie read only — zero network. The profile column is the source of
  // truth; the cookie mirrors it so first paint is already themed.
  const theme =
    (await cookies()).get("sculpt-theme")?.value === "spartan"
      ? "spartan"
      : "sculpt";

  return (
    <div data-theme={theme} className="min-h-dvh bg-bg text-ink">
      <ThemeSync theme={theme} />
      <div className="mx-auto max-w-md px-5 pt-[max(1.5rem,env(safe-area-inset-top))] pb-32">
        {children}
      </div>
      <TabBar />
      <CheerListener />
    </div>
  );
}
