"use client";

import { useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Camera, Columns2, Trash2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { recordProgressPhoto, deleteProgressPhoto } from "@/lib/actions";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sheet } from "@/components/ui/Sheet";
import { cn } from "@/lib/cn";

export interface PhotoItem {
  id: string;
  cycle: number;
  weekLabel: string;
  storagePath: string;
  url: string | null;
  createdAt: string;
}

export function PhotosClient({
  items,
  userId,
  cycle,
  weekIndex,
}: {
  items: PhotoItem[];
  userId: string;
  cycle: number;
  weekIndex: number;
}) {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [viewing, setViewing] = useState<PhotoItem | null>(null);
  const [compareMode, setCompareMode] = useState(false);
  const [compareIds, setCompareIds] = useState<string[]>([]);

  const byCycle = useMemo(() => {
    const map = new Map<number, PhotoItem[]>();
    for (const p of items) {
      const arr = map.get(p.cycle) ?? [];
      arr.push(p);
      map.set(p.cycle, arr);
    }
    return [...map.entries()].sort((a, b) => b[0] - a[0]);
  }, [items]);

  const comparePair = compareIds
    .map((id) => items.find((p) => p.id === id))
    .filter((p): p is PhotoItem => !!p);

  async function upload(file: File) {
    setUploading(true);
    try {
      const supabase = createClient();
      const ext = file.name.split(".").pop() || "jpg";
      const path = `${userId}/c${cycle}-w${weekIndex}-${Date.now()}.${ext}`;
      const { error } = await supabase.storage
        .from("progress-photos")
        .upload(path, file, { contentType: file.type });
      if (!error) {
        await recordProgressPhoto({
          cycle,
          weekLabel: `W${weekIndex}`,
          storagePath: path,
        });
        router.refresh();
      }
    } finally {
      setUploading(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  function tapPhoto(p: PhotoItem) {
    if (!compareMode) {
      setViewing(p);
      return;
    }
    setCompareIds((prev) =>
      prev.includes(p.id)
        ? prev.filter((id) => id !== p.id)
        : [...prev.slice(-1), p.id]
    );
  }

  return (
    <div>
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) upload(f);
        }}
      />

      <div className="mt-5 flex gap-2">
        <PillButton
          className="flex-1"
          disabled={uploading}
          onClick={() => fileRef.current?.click()}
        >
          <Camera size={16} strokeWidth={1.5} />
          {uploading ? "Uploading…" : `Add photo · C${cycle} W${weekIndex}`}
        </PillButton>
        {items.length >= 2 && (
          <PillButton
            variant={compareMode ? "sage" : "ghost"}
            aria-label="Compare weeks"
            onClick={() => {
              setCompareMode(!compareMode);
              setCompareIds([]);
            }}
          >
            <Columns2 size={16} strokeWidth={1.5} />
          </PillButton>
        )}
      </div>

      {compareMode && (
        <p className="mt-2 text-center text-xs text-ink-soft">
          Pick two photos to compare.
        </p>
      )}

      {items.length === 0 ? (
        <p className="mt-12 text-center text-sm font-light text-ink-soft">
          No photos yet — week one starts the story.
        </p>
      ) : (
        byCycle.map(([cyc, photos]) => (
          <section key={cyc} className="mt-7">
            <Eyebrow>CYCLE {cyc}</Eyebrow>
            <div className="mt-2 grid grid-cols-3 gap-2">
              {photos.map((p) => (
                <button
                  key={p.id}
                  onClick={() => tapPhoto(p)}
                  className={cn(
                    "relative aspect-[3/4] overflow-hidden rounded-2xl bg-white/50 transition-all",
                    compareMode && compareIds.includes(p.id) &&
                      "ring-2 ring-blush-deep ring-offset-2 ring-offset-bg"
                  )}
                >
                  {p.url && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={p.url}
                      alt={`${p.weekLabel} progress photo`}
                      className="h-full w-full object-cover"
                    />
                  )}
                  <MonoNumber className="absolute bottom-1.5 left-1.5 rounded-full bg-ink/50 px-2 py-0.5 text-[10px] text-white">
                    {p.weekLabel}
                  </MonoNumber>
                </button>
              ))}
            </div>
          </section>
        ))
      )}

      {/* full view */}
      <Sheet
        open={viewing != null}
        onClose={() => setViewing(null)}
        title={viewing ? `Cycle ${viewing.cycle} · ${viewing.weekLabel}` : ""}
      >
        {viewing?.url && (
          <div className="pb-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={viewing.url}
              alt="Progress photo"
              className="w-full rounded-2xl"
            />
            <div className="mt-4 flex justify-end">
              <PillButton
                variant="ghost"
                onClick={async () => {
                  await deleteProgressPhoto(viewing.id, viewing.storagePath);
                  setViewing(null);
                  router.refresh();
                }}
              >
                <Trash2 size={15} strokeWidth={1.5} /> Delete
              </PillButton>
            </div>
          </div>
        )}
      </Sheet>

      {/* week-vs-week compare */}
      <Sheet
        open={comparePair.length === 2}
        onClose={() => setCompareIds([])}
        title="Compare"
      >
        <div className="grid grid-cols-2 gap-2 pb-2">
          {comparePair.map((p) => (
            <figure key={p.id}>
              {p.url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={p.url}
                  alt={`${p.weekLabel}`}
                  className="aspect-[3/4] w-full rounded-2xl object-cover"
                />
              )}
              <figcaption className="mt-1 text-center">
                <MonoNumber className="text-[10px] text-ink-soft">
                  C{p.cycle} · {p.weekLabel}
                </MonoNumber>
              </figcaption>
            </figure>
          ))}
        </div>
      </Sheet>
    </div>
  );
}
