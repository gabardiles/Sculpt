// Supabase Edge Function: notify-feed
// -----------------------------------------------------------------------------
// Sends an iOS push when a friend cheers or comments on one of your feed posts.
// Wire it up as a Supabase **Database Webhook** (Dashboard → Database →
// Webhooks) on INSERT for `feed_cheers` and `feed_comments`, pointing at this
// function. The webhook delivers the new row; we resolve the post's owner and
// push to her registered devices.
//
// ⚠️ Requires the paid Apple Developer account. Set these function secrets
// (supabase secrets set ...):
//   APNS_KEY_ID         – the .p8 key id
//   APNS_TEAM_ID        – your Apple Developer team id
//   APNS_BUNDLE_ID      – com.sculpt.app
//   APNS_PRIVATE_KEY    – contents of the AuthKey_XXXX.p8 (PEM)
//   APNS_ENVIRONMENT    – "sandbox" (dev) or "production"
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY – auto-present in the function env
//
// Until those exist this function is harmless — deploy it whenever you're ready.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface WebhookPayload {
  type: "INSERT";
  table: "feed_cheers" | "feed_comments";
  record: Record<string, unknown>;
}

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  try {
    const payload = (await req.json()) as WebhookPayload;
    const { table, record } = payload;

    const postId = record.post_id as string;
    const actorId = record.user_id as string;
    if (!postId || !actorId) return ok("ignored");

    // Who owns the post being interacted with?
    const { data: post } = await admin
      .from("feed_posts")
      .select("user_id, type, body")
      .eq("id", postId)
      .maybeSingle();
    if (!post) return ok("no post");

    const recipientId = post.user_id as string;
    if (recipientId === actorId) return ok("self"); // never notify yourself

    // The actor's display name.
    const { data: actor } = await admin
      .from("profiles")
      .select("name")
      .eq("id", actorId)
      .maybeSingle();
    const actorName = (actor?.name as string) ?? "A friend";

    const title = "Sculpt";
    const message =
      table === "feed_cheers"
        ? `${actorName} cheered your ${post.type === "pb" ? "PB" : "post"} 👏`
        : `${actorName} commented: ${(record.body as string)?.slice(0, 80) ?? ""}`;

    // The recipient's devices.
    const { data: tokens } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", recipientId)
      .eq("platform", "ios");
    if (!tokens?.length) return ok("no devices");

    await Promise.all(
      tokens.map((t) => sendAPNs((t as { token: string }).token, title, message, postId)),
    );
    return ok("sent", tokens.length);
  } catch (e) {
    console.error("notify-feed error", e);
    return new Response("error", { status: 500 });
  }
});

function ok(reason: string, count = 0) {
  return new Response(JSON.stringify({ ok: true, reason, count }), {
    headers: { "content-type": "application/json" },
  });
}

// --- APNs (token-based, HTTP/2) ---------------------------------------------
// Builds a short-lived ES256 JWT from your .p8 key and posts the alert.

let cachedJWT: { token: string; at: number } | null = null;

async function apnsJWT(): Promise<string> {
  // APNs tokens are valid up to an hour; refresh every ~50 min.
  if (cachedJWT && Date.now() - cachedJWT.at < 50 * 60 * 1000) return cachedJWT.token;

  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_PRIVATE_KEY")!;

  const header = { alg: "ES256", kid: keyId };
  const claims = { iss: teamId, iat: Math.floor(Date.now() / 1000) };
  const enc = (o: unknown) => base64url(new TextEncoder().encode(JSON.stringify(o)));
  const signingInput = `${enc(header)}.${enc(claims)}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(pem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const token = `${signingInput}.${base64url(new Uint8Array(sig))}`;
  cachedJWT = { token, at: Date.now() };
  return token;
}

async function sendAPNs(deviceToken: string, title: string, body: string, postId: string) {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.sculpt.app";
  const env = Deno.env.get("APNS_ENVIRONMENT") ?? "sandbox";
  const host = env === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const jwt = await apnsJWT();

  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: { alert: { title, body }, sound: "default" },
      postId,
    }),
  });
  if (!res.ok) {
    const reason = await res.text();
    // 410 = the device unregistered; prune its token so we stop trying.
    if (res.status === 410) {
      await admin.from("device_tokens").delete().eq("token", deviceToken);
    }
    console.error("APNs", res.status, reason);
  }
}

function base64url(bytes: Uint8Array): string {
  let s = btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}
