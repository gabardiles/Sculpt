import { redirect } from "next/navigation";
import { requireUser, getProfile } from "@/lib/data";
import { Eyebrow } from "@/components/ui/MonoNumber";
import { InviteForm } from "@/components/admin/InviteForm";

export default async function AdminPage() {
  const { supabase, user } = await requireUser();
  const profile = await getProfile(supabase, user.id);
  if (!profile?.is_admin) redirect("/");

  return (
    <main className="animate-fade-in">
      <Eyebrow>ADMIN</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">Invite someone</h1>
      <p className="mt-2 text-sm font-light text-ink-soft">
        This creates her account — she signs in with a 6-digit code sent to
        her email. No password, no public signup.
      </p>
      <InviteForm />
    </main>
  );
}
