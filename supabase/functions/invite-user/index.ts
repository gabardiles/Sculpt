// Supabase Edge Function: invite-user
// -----------------------------------------------------------------------------
// Native counterpart of the inviteUser server action (src/lib/actions.ts).
// An admin invites someone by email: the account is created (active + auto-
// approved, no password) and a sign-in email is sent. Invite-only sign-up, so
// this is the only way new accounts appear.
//
// Deploy:  supabase functions deploy invite-user
// Secrets (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are present by default):
//   supabase secrets set RESEND_API_KEY=re_...   RESEND_FROM=sculpt@yourdomain.com
//   supabase secrets set NEXT_PUBLIC_SITE_URL=https://your-app-url   # optional
// Without RESEND_*, it falls back to Supabase's own OTP mailer.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), { status: s, headers: { ...cors, "content-type": "application/json" } });

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return json({ ok: false, error: "unauthorized" }, 401);

  // Identify the caller and confirm they're an admin.
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
  const { data: who } = await caller.auth.getUser();
  if (!who?.user) return json({ ok: false, error: "unauthorized" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: profile } = await admin
    .from("profiles").select("is_admin").eq("id", who.user.id).maybeSingle();
  if (!profile?.is_admin) return json({ ok: false, error: "Not allowed." }, 403);

  // Validate the invitee email.
  let email = "";
  try { email = String((await req.json())?.email ?? "").trim().toLowerCase(); } catch { /* ignore */ }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json({ ok: false, error: "That doesn't look like an email." });
  }

  // 1. Create the account — active and auto-approved (email_confirm), no password.
  const { error: createError } = await admin.auth.admin.createUser({
    email, email_confirm: true, user_metadata: { invited_by: who.user.id },
  });
  const alreadyExisted = !!createError && createError.message.toLowerCase().includes("already");
  if (createError && !alreadyExisted) return json({ ok: false, error: createError.message });

  // 2. Email her a sign-in code. createUser() alone sends nothing — prefer a
  //    branded Resend invite when configured, else Supabase's OTP mailer.
  let emailSent = false;
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const resendFrom = Deno.env.get("RESEND_FROM");
  if (resendKey && resendFrom) {
    const site = Deno.env.get("NEXT_PUBLIC_SITE_URL") ?? "https://sculpt-gabardiles-projects.vercel.app";
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: `Sculpt <${resendFrom}>`, to: email, subject: "You're invited to Sculpt",
          html: `<div style="font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;max-width:420px;margin:0 auto;padding:32px 24px;color:#2B2422;background:#FBF7F6;border-radius:24px">
  <p style="font-size:11px;letter-spacing:2px;color:#6F635E;margin:0">TRAINING TRACKER</p>
  <h1 style="font-weight:300;letter-spacing:4px;margin:8px 0 24px">SCULPT</h1>
  <p style="font-size:15px;line-height:1.6;font-weight:300">You've been invited. Your account is ready — no password, ever.</p>
  <ol style="font-size:14px;line-height:1.9;font-weight:300;padding-left:20px">
    <li>Open the Sculpt app (or <a href="${site}" style="color:#B97D77">${site.replace("https://", "")}</a>)</li>
    <li>Sign in with <strong>${email}</strong></li>
    <li>A 6-digit code lands here — type it in, and you're training</li>
  </ol>
</div>`,
        }),
      });
      emailSent = res.ok;
    } catch { emailSent = false; }
  } else {
    const { error: sendError } = await caller.auth.signInWithOtp({ email, options: { shouldCreateUser: false } });
    emailSent = !sendError;
  }

  return json({ ok: true, emailSent });
});
