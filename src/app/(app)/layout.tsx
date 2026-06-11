import { TabBar } from "@/components/nav/TabBar";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-dvh">
      <div className="mx-auto max-w-md px-5 pt-[max(1.5rem,env(safe-area-inset-top))] pb-32">
        {children}
      </div>
      <TabBar />
    </div>
  );
}
