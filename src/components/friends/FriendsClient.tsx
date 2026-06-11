"use client";

import { useRef, useState } from "react";
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
import { validateImageFile } from "@/lib/uploads";
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
  cheerNames: string[];
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
  }

  async function postPhoto(file: File) {
    const problem = validateImageFile(file);
    if (problem) {
      alert(problem);
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
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
      }
    } finally {
      setPosting(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  return (
    <div>
      {/* one row: composer + photo + send + friends/invite. Feed leads. */}
      <form onSubmit={postMessage} className="mt-4 flex items-center gap-2">
        {/* No `capture` attr: mobile offers camera OR photo library. */}
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
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
          className="h-12 min-w-0 flex-1 rounded-full border border-ink/15 bg-surface px-5 text-sm outline-none focus:border-blush-deep"
        />
        <button
          type="button"
          aria-label="Post a gym photo"
          disabled={posting}
          onClick={() => fileRef.current?.click()}
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-ink/15 bg-surface text-ink-soft active:bg-ink/5"
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
        <button
          type="button"
          aria-label="Friends and invites"
          onClick={() => setManageOpen(true)}
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-ink/15 bg-surface text-ink-soft active:bg-ink/5"
        >
          <Users size={18} strokeWidth={1.5} />
        </button>
      </form>

      {/* feed */}
      {feed.length === 0 ? (
        <p className="mt-12 text-center text-sm font-light text-ink-soft">
          {friends.length === 0 ? (
            <>
              Add a friend with her code — tap{" "}
              <Users size={14} className="inline" strokeWidth={1.5} /> above to
              start.
            </>
          ) : (
            "Quiet for now. Your next workout will show up here."
          )}
        </p>
      ) : (
        <ul className="mt-6 flex flex-col gap-3">
          {feed.map((item) => (
            <li key={item.id}>
              <FeedCard item={item} />
            </li>
          ))}
        </ul>
      )}

      {/* friends, codes & invites — tucked away in one sheet */}
      <Sheet open={manageOpen} onClose={() => setManageOpen(false)} title="Friends">
        <div className="pb-2">
          <Eyebrow>YOUR CODE</Eyebrow>
          <button
            onClick={copyCode}
            className="mt-0.5 flex min-h-12 items-center gap-2"
            aria-label="Copy your friend code"
          >
            <MonoNumber className="text-2xl tracking-[0.2em]">
              {myCode}
            </MonoNumber>
            {copied ? (
              <Check size={16} strokeWidth={1.8} className="text-sage-deep" />
            ) : (
              <Copy size={16} strokeWidth={1.5} className="text-ink-soft" />
            )}
          </button>

          <form onSubmit={addFriend} className="mt-4 flex gap-2">
            <input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="Friend's code"
              maxLength={6}
              className="h-12 min-w-0 flex-1 rounded-full border border-ink/15 bg-surface px-4 text-center font-mono text-sm tracking-[0.2em] uppercase outline-none focus:border-blush-deep"
            />
            <PillButton type="submit" disabled={adding || !code.trim()} className="shrink-0">
              <UserPlus size={16} strokeWidth={1.5} /> Add
            </PillButton>
          </form>
          {addError && (
            <p className="mt-2 text-center text-xs text-blush-deep">{addError}</p>
          )}

          {friends.length > 0 && (
            <ul className="mt-5 flex flex-col gap-2">
              {friends.map((f) => (
                <li
                  key={f.id}
                  className="glass flex items-center justify-between px-4 py-3"
                >
                  <span className="text-sm">{f.name}</span>
                  <button
                    aria-label={`Remove ${f.name}`}
                    onClick={() => removeFriend(f.id)}
                    className="flex h-10 w-10 items-center justify-center rounded-full text-ink-soft/80 active:bg-ink/5"
                  >
                    <Trash2 size={15} strokeWidth={1.5} />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Sheet>
    </div>
  );
}

function FeedCard({ item }: { item: FeedItem }) {
  const [cheered, setCheered] = useState(item.cheeredByMe);
  // Optimistic names so the cheer pops instantly, no waiting on the server.
  const [names, setNames] = useState<string[]>(item.cheerNames);

  async function cheer() {
    const next = !cheered;
    setCheered(next);
    setNames((prev) =>
      next ? [...prev.filter((n) => n !== "You"), "You"] : prev.filter((n) => n !== "You")
    );
    await toggleCheer(item.id, next);
  }

  const cheerLabel =
    names.length === 0
      ? "Cheer"
      : names.length <= 2
        ? names.join(" & ")
        : `${names.slice(0, 2).join(", ")} +${names.length - 2}`;

  const phase = item.metadata?.phase as string | undefined;
  const dayName = item.metadata?.day_name as string | undefined;

  // Workouts and PBs are compact: everything on one row.
  if (item.type === "workout" || item.type === "pb") {
    return (
      <Card done={item.type === "workout"} className="flex items-center gap-2.5 px-4 py-3">
        {item.type === "workout" ? (
          <Check size={17} strokeWidth={2.2} className="shrink-0 text-sage-deep" />
        ) : (
          <TrendingUp size={17} strokeWidth={1.9} className="shrink-0 text-blush-deep" />
        )}
        <span className="min-w-0 flex-1 truncate text-sm">
          <span className="font-medium">{item.authorName}</span>{" "}
          <span className="font-light">
            {item.type === "workout" ? (dayName ?? item.body) : item.body}
          </span>
          {phase && (
            <MonoNumber className="ml-1.5 text-[11px] uppercase text-ink-soft">
              {phase}
            </MonoNumber>
          )}
          <MonoNumber className="ml-1.5 text-[11px] text-ink-soft">
            {formatDay(item.createdAt)}
          </MonoNumber>
        </span>
        <button
          onClick={cheer}
          aria-label={cheered ? "Remove cheer" : "Cheer"}
          className="flex min-h-12 shrink-0 items-center gap-1.5 rounded-full px-2"
        >
          <Heart
            size={20}
            strokeWidth={1.6}
            className={cn(
              "transition-colors",
              cheered
                ? "fill-blush-deep text-blush-deep heart-pop"
                : "text-ink-soft"
            )}
          />
          {names.length > 0 && (
            <span className="max-w-24 truncate text-xs font-medium text-blush-deep">
              {cheerLabel}
            </span>
          )}
        </button>
      </Card>
    );
  }

  return (
    <Card className="p-4">
      <div className="flex items-baseline justify-between">
        <span className="text-sm font-medium">{item.authorName}</span>
        <MonoNumber className="text-[11px] text-ink-soft">
          {formatDay(item.createdAt)}
        </MonoNumber>
      </div>

      <div className="mt-1.5">
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

      <div className="mt-3 flex items-center justify-between">
        <button
          onClick={cheer}
          aria-label={cheered ? "Remove cheer" : "Cheer"}
          className={cn(
            "-ml-1 flex min-h-12 items-center gap-2 rounded-full px-3 transition-colors",
            cheered ? "bg-blush/30" : "active:bg-blush/20"
          )}
        >
          <Heart
            size={22}
            strokeWidth={1.6}
            className={cn(
              "transition-colors",
              cheered
                ? "fill-blush-deep text-blush-deep heart-pop"
                : "text-ink-soft"
            )}
          />
          <span
            className={cn(
              "text-sm",
              names.length
                ? "font-medium text-blush-deep"
                : "font-light text-ink-soft"
            )}
          >
            {cheerLabel}
          </span>
        </button>
        {item.mine && (item.type === "message" || item.type === "photo") && (
          <button
            aria-label="Delete post"
            onClick={() => deleteFeedPost(item.id, item.storagePath)}
            className="flex h-10 w-10 items-center justify-center rounded-full text-ink-soft/80 active:bg-ink/5"
          >
            <Trash2 size={14} strokeWidth={1.5} />
          </button>
        )}
      </div>
    </Card>
  );
}
