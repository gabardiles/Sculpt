import { redirect } from "next/navigation";
import { requireUser, getProfile } from "@/lib/data";
import { isAiConfigured } from "@/lib/physique";
import { ReportClient } from "@/components/report/ReportClient";
import type { FitnessReport } from "@/lib/types";

export default async function ReportPage() {
  const { supabase, user } = await requireUser();
  const profile = await getProfile(supabase, user.id);
  if (!profile?.name) redirect("/onboarding");

  const [{ data: reportRows }, { count: photoCount, data: latestPhoto }, { data: bw }] =
    await Promise.all([
      supabase
        .from("fitness_reports")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(8),
      supabase
        .from("progress_photos")
        .select("created_at", { count: "exact" })
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(1),
      supabase
        .from("body_weight")
        .select("weight_kg")
        .eq("user_id", user.id)
        .order("date", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ]);

  const reports = (reportRows ?? []) as FitnessReport[];
  const latest = reports[0] ?? null;
  const latestPhotoAt =
    ((latestPhoto ?? []) as { created_at: string }[])[0]?.created_at ?? null;
  // A photo added after the current report means there's something fresh to analyze.
  const hasNewerPhoto =
    !!latestPhotoAt && !!latest && latestPhotoAt > latest.created_at;

  return (
    <ReportClient
      needsSetup={!profile.gender}
      aiConfigured={isAiConfigured()}
      photoCount={photoCount ?? 0}
      hasNewerPhoto={hasNewerPhoto}
      latest={latest}
      history={reports}
      profile={{
        gender: profile.gender,
        heightCm: profile.height_cm,
        goalNote: profile.goal_note,
      }}
      latestWeight={(bw?.weight_kg as number | null) ?? null}
    />
  );
}
