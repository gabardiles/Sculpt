import { redirect } from "next/navigation";
import { requireUser, getProfile } from "@/lib/data";
import { Eyebrow } from "@/components/ui/MonoNumber";
import { InviteForm } from "@/components/admin/InviteForm";

export default async function AdminPage() {
  const { supabase, user } = await requireUser();
  const profile = await getProfile(supabase, user.id);
  if (!profile?.is_admin) redirect("/");

  return (
    <main className="animate-fade-up">
      <Eyebrow>ADMIN</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">Invite someone</h1>
      <p className="mt-2 text-sm font-light text-ink-soft">
        She gets a magic link by email — no password, no public signup.
      </p>
      <InviteForm />
    </main>
  );
}
