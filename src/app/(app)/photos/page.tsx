import { requireUser, getActiveProgram, getCycleLogs } from "@/lib/data";
import { deriveCycleState } from "@/lib/cycle";
import { Eyebrow } from "@/components/ui/MonoNumber";
import { PhotosClient, type PhotoItem } from "@/components/photos/PhotosClient";
import type { ProgressPhoto } from "@/lib/types";

export default async function PhotosPage() {
  const { supabase, user } = await requireUser();

  const program = await getActiveProgram(supabase, user.id);
  const dayIds = program?.days.map((d) => d.id) ?? [];
  const logs = program ? await getCycleLogs(supabase, user.id, dayIds) : [];
  const state = deriveCycleState(logs, dayIds, program?.cycle_floor ?? 1);

  const { data } = await supabase
    .from("progress_photos")
    .select("*")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false });
  const photos = (data ?? []) as ProgressPhoto[];

  // Signed URLs (private bucket) — 1 hour is plenty for a browsing session.
  let items: PhotoItem[] = [];
  if (photos.length) {
    const { data: signed } = await supabase.storage
      .from("progress-photos")
      .createSignedUrls(photos.map((p) => p.storage_path), 3600);
    items = photos.map((p, i) => ({
      id: p.id,
      cycle: p.cycle_number,
      weekLabel: p.week_label,
      storagePath: p.storage_path,
      url: signed?.[i]?.signedUrl ?? null,
      createdAt: p.created_at,
    }));
  }

  return (
    <main className="animate-fade-up">
      <Eyebrow>PROGRESS</Eyebrow>
      <h1 className="mt-1 text-3xl font-light tracking-wide">Photos</h1>
      <p className="mt-2 text-sm font-light text-ink-soft">
        One per week. Private — only you can see these.
      </p>

      <PhotosClient
        items={items}
        userId={user.id}
        cycle={state.cycle}
        weekIndex={state.weekIndex}
      />
    </main>
  );
}
