"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/cn";

interface Toast {
  id: string;
  emoji: string;
  text: string;
}

/**
 * Live cheers: when a friend cheers one of your posts or sends a message,
 * a small bubble pops in the corner — wherever you are in the app,
 * including mid-workout. Powered by Supabase Realtime; RLS decides what
 * each subscriber may see.
 */
export function CheerListener() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  function push(emoji: string, text: string) {
    const id = crypto.randomUUID();
    setToasts((prev) => [...prev.slice(-2), { id, emoji, text }]);
    setTimeout(
      () => setToasts((prev) => prev.filter((t) => t.id !== id)),
      6000
    );
  }

  useEffect(() => {
    const supabase = createClient();
    let cancelled = false;

    const channelPromise = (async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      const userId = session?.user?.id;
      if (!userId || cancelled) return null;

      return supabase
        .channel("live-cheers")
        .on(
          "postgres_changes",
          { event: "INSERT", schema: "public", table: "feed_cheers" },
          async (payload) => {
            const cheer = payload.new as { post_id: string; user_id: string };
            if (cheer.user_id === userId) return;
            const [{ data: post }, { data: who }] = await Promise.all([
              supabase
                .from("feed_posts")
                .select("user_id")
                .eq("id", cheer.post_id)
                .maybeSingle(),
              supabase
                .from("profiles")
                .select("name")
                .eq("id", cheer.user_id)
                .maybeSingle(),
            ]);
            // Only celebrate cheers on YOUR posts.
            if (post?.user_id !== userId) return;
            push("👏", `${who?.name ?? "A friend"} cheers you on!`);
          }
        )
        .on(
          "postgres_changes",
          { event: "INSERT", schema: "public", table: "feed_posts" },
          async (payload) => {
            const post = payload.new as {
              user_id: string;
              type: string;
              body: string | null;
            };
            if (post.user_id === userId || post.type !== "message" || !post.body)
              return;
            const { data: who } = await supabase
              .from("profiles")
              .select("name")
              .eq("id", post.user_id)
              .maybeSingle();
            push("💬", `${who?.name ?? "A friend"}: “${post.body}”`);
          }
        )
        .on(
          "postgres_changes",
          { event: "INSERT", schema: "public", table: "feed_comments" },
          async (payload) => {
            const c = payload.new as {
              post_id: string;
              user_id: string;
              body: string;
            };
            if (c.user_id === userId) return;
            const [{ data: post }, { data: who }] = await Promise.all([
              supabase
                .from("feed_posts")
                .select("user_id")
                .eq("id", c.post_id)
                .maybeSingle(),
              supabase
                .from("profiles")
                .select("name")
                .eq("id", c.user_id)
                .maybeSingle(),
            ]);
            // Only notify on comments on YOUR posts.
            if (post?.user_id !== userId) return;
            push("💬", `${who?.name ?? "A friend"}: “${c.body}”`);
          }
        )
        .subscribe();
    })();

    return () => {
      cancelled = true;
      channelPromise.then((ch) => {
        if (ch) supabase.removeChannel(ch);
      });
    };
  }, []);

  if (!toasts.length) return null;

  return (
    <div className="pointer-events-none fixed inset-x-4 bottom-28 z-[70] flex flex-col items-end gap-2">
      {toasts.map((t) => (
        <button
          key={t.id}
          onClick={() =>
            setToasts((prev) => prev.filter((x) => x.id !== t.id))
          }
          className={cn(
            "pointer-events-auto glass flex max-w-full items-center gap-2.5 px-4 py-3",
            "animate-fade-up text-left"
          )}
        >
          <span className="heart-pop text-xl leading-none">{t.emoji}</span>
          <span className="truncate text-sm font-light">{t.text}</span>
        </button>
      ))}
    </div>
  );
}
