"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Camera,
  Check,
  Copy,
  Heart,
  Send,
  Trash2,
  TrendingUp,
  UserPlus,
  Users,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import {
  addFriendByCode,
  createFeedPost,
  deleteFeedPost,
  removeFriend,
  toggleCheer,
} from "@/lib/actions";
import { Card } from "@/components/ui/Card";
import { PillButton } from "@/components/ui/PillButton";
import { Eyebrow, MonoNumber } from "@/components/ui/MonoNumber";
import { Sheet } from "@/components/ui/Sheet";
import type { FeedPostType } from "@/lib/types";
import { formatDay } from "@/lib/format";
import { cn } from "@/lib/cn";

export interface FriendRow {
  id: string;
  name: string;
}

export interface FeedItem {
  id: string;
  userId: string;
  authorName: string;
  mine: boolean;
  type: FeedPostType;
  body: string | null;
  storagePath: string | null;
  photoUrl: string | null;
  metadata: Record<string, unknown>;
  createdAt: string;
  cheerCount: number;
  cheeredByMe: boolean;
}

export function FriendsClient({
  myCode,
  userId,
  friends,
  feed,
}: {
  myCode: string;
  userId: string;
  friends: FriendRow[];
  feed: FeedItem[];
}) {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [copied, setCopied] = useState(false);
  const [code, setCode] = useState("");
  const [addError, setAddError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [message, setMessage] = useState("");
  const [posting, setPosting] = useState(false);
  const [manageOpen, setManageOpen] = useState(false);

  async function copyCode() {
    try {
      await navigator.clipboard.writeText(myCode);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard unavailable — the code is visible anyway.
    }
  }

  async function addFriend(e: React.FormEvent) {
    e.preventDefault();
    if (!code.trim() || adding) return;
    setAdding(true);
    setAddError(null);
    const fd = new FormData();
    fd.set("code", code);
    const res = await addFriendByCode(fd);
    if (res.ok) {
      setCode("");
      router.refresh();
    } else {
      setAddError(res.error);
    }
    setAdding(false);
  }

  async function postMessage(e: React.FormEvent) {
    e.preventDefault();
    if (!message.trim() || posting) return;
    setPosting(true);
    await createFeedPost({ type: "message", body: message, storagePath: null });
    setMessage("");
    setPosting(false);
    router.refresh();
  }

  async function postPhoto(file: File) {
    setPosting(true);
    try {
      const supabase = createClient();
      const ext = file.name.split(".").pop() || "jpg";
      const path = `${userId}/${Date.now()}.${ext}`;
      const { error } = await supabase.storage
        .from("feed-photos")
        .upload(path, file, { contentType: file.type });
      if (!error) {
        await createFeedPost({
          type: "photo",
          body: message.trim() || null,
          storagePath: path,
        });
        setMessage("");
        router.refresh();
      }
    } finally {
      setPosting(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  return (
    <div>
      {/* my code + add friend */}
      <Card className="mt-5 p-4">
        <div className="flex items-center justify-between">
          <div>
            <Eyebrow>YOUR CODE</Eyebrow>
            <button
              onClick={copyCode}
              className="mt-0.5 flex min-h-10 items-center gap-2"
              aria-label="Copy your friend code"
            >
              <MonoNumber className="text-xl tracking-[0.2em]">
                {myCode}
              </MonoNumber>
              {copied ? (
                <Check size={15} strokeWidth={1.8} className="text-sage-deep" />
              ) : (
                <Copy size={15} strokeWidth={1.5} className="text-ink-soft" />
              )}
            </button>
          </div>
          {friends.length > 0 && (
            <button
              onClick={() => setManageOpen(true)}
              className="flex min-h-12 items-center gap-1.5 rounded-full px-3 text-ink-soft active:bg-ink/5"
            >
              <Users size={16} strokeWidth={1.5} />
              <MonoNumber className="text-xs">{friends.length}</MonoNumber>
            </button>
          )}
        </div>

        <form onSubmit={addFriend} className="mt-3 flex gap-2">
          <input
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            placeholder="Friend's code"
            maxLength={6}
            className="h-12 min-w-0 flex-1 rounded-full border border-ink/15 bg-white/60 px-4 text-center font-mono text-sm tracking-[0.2em] uppercase outline-none focus:border-blush-deep"
          />
          <PillButton type="submit" disabled={adding || !code.trim()} className="shrink-0">
            <UserPlus size={16} strokeWidth={1.5} /> Add
          </PillButton>
        </form>
        {addError && (
          <p className="mt-2 text-center text-xs text-blush-deep">{addError}</p>
        )}
      </Card>

      {/* composer */}
      <form onSubmit={postMessage} className="mt-4 flex items-center gap-2">
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          capture="environment"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) postPhoto(f);
          }}
        />
        <input
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Say something nice…"
          maxLength={200}
          className="h-12 min-w-0 flex-1 rounded-full border border-ink/15 bg-white/60 px-5 text-sm outline-none focus:border-blush-deep"
        />
        <button
          type="button"
          aria-label="Post a gym photo"
          disabled={posting}
          onClick={() => fileRef.current?.click()}
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-ink/15 bg-white/60 text-ink-soft active:bg-ink/5"
        >
          <Camera size={18} strokeWidth={1.5} />
        </button>
        <button
          type="submit"
          aria-label="Send message"
          disabled={posting || !message.trim()}
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-blush text-ink disabled:opacity-40"
        >
          <Send size={17} strokeWidth={1.5} />
        </button>
      </form>

      {/* feed */}
      {feed.length === 0 ? (
        <p className="mt-12 text-center text-sm font-light text-ink-soft">
          {friends.length === 0
            ? "Add a friend with her code — the feed starts there."
            : "Quiet for now. Your next workout will show up here."}
        </p>
      ) : (
        <ul className="mt-6 flex flex-col gap-3">
          {feed.map((item) => (
            <li key={item.id}>
              <FeedCard item={item} onChanged={() => router.refresh()} />
            </li>
          ))}
        </ul>
      )}

      {/* manage friends */}
      <Sheet open={manageOpen} onClose={() => setManageOpen(false)} title="Friends">
        <ul className="flex flex-col gap-2 pb-2">
          {friends.map((f) => (
            <li
              key={f.id}
              className="glass flex items-center justify-between px-4 py-3"
            >
              <span className="text-sm">{f.name}</span>
              <button
                aria-label={`Remove ${f.name}`}
                onClick={async () => {
                  await removeFriend(f.id);
                  router.refresh();
                }}
                className="flex h-10 w-10 items-center justify-center rounded-full text-ink-soft/60 active:bg-ink/5"
              >
                <Trash2 size={15} strokeWidth={1.5} />
              </button>
            </li>
          ))}
        </ul>
      </Sheet>
    </div>
  );
}

function FeedCard({
  item,
  onChanged,
}: {
  item: FeedItem;
  onChanged: () => void;
}) {
  const [cheered, setCheered] = useState(item.cheeredByMe);
  const [count, setCount] = useState(item.cheerCount);

  async function cheer() {
    const next = !cheered;
    setCheered(next);
    setCount((c) => c + (next ? 1 : -1));
    await toggleCheer(item.id, next);
  }

  const phase = item.metadata?.phase as string | undefined;

  return (
    <Card
      done={item.type === "workout"}
      className="p-4"
    >
      <div className="flex items-baseline justify-between">
        <span className="text-sm font-medium">{item.authorName}</span>
        <MonoNumber className="text-[10px] text-ink-soft">
          {formatDay(item.createdAt)}
        </MonoNumber>
      </div>

      <div className="mt-1.5">
        {item.type === "workout" && (
          <p className="flex items-center gap-2 text-sm font-light">
            <Check size={15} strokeWidth={2} className="shrink-0 text-sage-deep" />
            {item.body}
            {phase && (
              <MonoNumber className="text-[10px] uppercase text-ink-soft">
                {phase}
              </MonoNumber>
            )}
          </p>
        )}
        {item.type === "pb" && (
          <p className="flex items-center gap-2 text-sm">
            <TrendingUp size={15} strokeWidth={1.8} className="shrink-0 text-blush-deep" />
            <span className="font-light">{item.body}</span>
          </p>
        )}
        {item.type === "message" && (
          <p className="text-sm font-light leading-relaxed">“{item.body}”</p>
        )}
        {item.type === "photo" && (
          <div>
            {item.photoUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={item.photoUrl}
                alt="Gym photo"
                className="mt-1 w-full rounded-2xl object-cover"
              />
            )}
            {item.body && (
              <p className="mt-2 text-sm font-light">{item.body}</p>
            )}
          </div>
        )}
      </div>

      <div className="mt-2 flex items-center justify-between">
        <button
          onClick={cheer}
          aria-label={cheered ? "Remove cheer" : "Cheer"}
          className="flex min-h-10 items-center gap-1.5 rounded-full px-2 -ml-2"
        >
          <Heart
            size={16}
            strokeWidth={1.6}
            className={cn(
              "transition-colors",
              cheered ? "fill-blush-deep text-blush-deep" : "text-ink-soft/60"
            )}
          />
          {count > 0 && (
            <MonoNumber className="text-xs text-ink-soft">{count}</MonoNumber>
          )}
        </button>
        {item.mine && (item.type === "message" || item.type === "photo") && (
          <button
            aria-label="Delete post"
            onClick={async () => {
              await deleteFeedPost(item.id, item.storagePath);
              onChanged();
            }}
            className="flex h-10 w-10 items-center justify-center rounded-full text-ink-soft/40 active:bg-ink/5"
          >
            <Trash2 size={14} strokeWidth={1.5} />
          </button>
        )}
      </div>
    </Card>
  );
}
