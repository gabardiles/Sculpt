import { requireUser, getProfile } from "@/lib/data";
import {
  FriendsClient,
  type FeedItem,
  type FriendRow,
} from "@/components/friends/FriendsClient";
import type { FeedPost } from "@/lib/types";

export default async function FriendsPage() {
  const { supabase, user } = await requireUser();

  const [profile, { data: friendRows }] = await Promise.all([
    getProfile(supabase, user.id),
    supabase.from("friends").select("friend_id").eq("user_id", user.id),
  ]);
  const friendIds = ((friendRows ?? []) as { friend_id: string }[]).map(
    (r) => r.friend_id
  );

  // Names (RLS lets friends read each other's profile) + the shared feed.
  const [{ data: people }, { data: postsData }] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, name")
      .in("id", [user.id, ...friendIds]),
    supabase
      .from("feed_posts")
      .select("*")
      .in("user_id", [user.id, ...friendIds])
      .order("created_at", { ascending: false })
      .limit(60),
  ]);
  const nameById = new Map(
    ((people ?? []) as { id: string; name: string | null }[]).map((p) => [
      p.id,
      p.name ?? "Someone",
    ])
  );
  const friends: FriendRow[] = friendIds.map((id) => ({
    id,
    name: nameById.get(id) ?? "Someone",
  }));
  const posts = (postsData ?? []) as FeedPost[];

  // Cheers for the visible posts.
  const { data: cheersData } = posts.length
    ? await supabase
        .from("feed_cheers")
        .select("post_id, user_id")
        .in("post_id", posts.map((p) => p.id))
    : { data: [] };
  const cheers = (cheersData ?? []) as { post_id: string; user_id: string }[];

  // Signed URLs for photo posts.
  const photoPaths = posts
    .filter((p) => p.type === "photo" && p.storage_path)
    .map((p) => p.storage_path!) as string[];
  const urlByPath = new Map<string, string>();
  if (photoPaths.length) {
    const { data: signed } = await supabase.storage
      .from("feed-photos")
      .createSignedUrls(photoPaths, 3600);
    photoPaths.forEach((path, i) => {
      const url = signed?.[i]?.signedUrl;
      if (url) urlByPath.set(path, url);
    });
  }

  const items: FeedItem[] = posts.map((p) => ({
    id: p.id,
    userId: p.user_id,
    authorName: p.user_id === user.id ? "You" : nameById.get(p.user_id) ?? "Someone",
    mine: p.user_id === user.id,
    type: p.type,
    body: p.body,
    storagePath: p.storage_path,
    photoUrl: p.storage_path ? urlByPath.get(p.storage_path) ?? null : null,
    metadata: p.metadata,
    createdAt: p.created_at,
    cheerCount: cheers.filter((c) => c.post_id === p.id).length,
    cheeredByMe: cheers.some((c) => c.post_id === p.id && c.user_id === user.id),
    cheerNames: cheers
      .filter((c) => c.post_id === p.id)
      .map((c) =>
        c.user_id === user.id ? "You" : nameById.get(c.user_id) ?? "Someone"
      ),
  }));

  return (
    <main className="animate-fade-in">
      <FriendsClient
        myCode={profile?.friend_code ?? ""}
        userId={user.id}
        friends={friends}
        feed={items}
      />
    </main>
  );
}
