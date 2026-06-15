// Supabase Edge Function: fitness-report
// -----------------------------------------------------------------------------
// The native counterpart of src/lib/physique.ts + the generateFitnessReport
// server action. Analyzes a member's latest progress photos with Claude vision
// and stores a fitness_reports row. The iOS app calls this with the member's
// auth token (functions.invoke), so RLS applies to every read/write.
//
// Deploy:  supabase functions deploy fitness-report
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
// (SUPABASE_URL + SUPABASE_ANON_KEY are present in the function env by default.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "claude-opus-4-8";
const METRIC_KEYS = ["conditioning", "core", "upper", "lower", "arms", "proportion"];
const FOCUS_MUSCLES = ["glutes", "hamstrings", "quads", "back", "chest", "shoulders", "arms", "core", "calves"];

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ ok: false, error: "not_configured" });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return json({ ok: false, error: "unauthorized" }, 401);

  // A client bound to the caller's JWT — RLS scopes every query to her rows.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData } = await supabase.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ ok: false, error: "unauthorized" }, 401);

  // Profile gate: the physique target needs a chosen gender.
  const { data: profile } = await supabase
    .from("profiles").select("gender, height_cm, goal_note").eq("id", user.id).maybeSingle();
  if (!profile?.gender) return json({ ok: false, error: "needs_setup" });

  const [{ data: photos }, { data: bw }] = await Promise.all([
    supabase.from("progress_photos").select("storage_path")
      .eq("user_id", user.id).order("created_at", { ascending: false }).limit(3),
    supabase.from("body_weight").select("weight_kg")
      .eq("user_id", user.id).order("date", { ascending: false }).limit(1).maybeSingle(),
  ]);

  const paths = (photos ?? []).map((p: { storage_path: string }) => p.storage_path);
  if (!paths.length) return json({ ok: false, error: "needs_photo" });

  // Download the private photos and inline them for the vision call.
  const images: { base64: string; mediaType: string }[] = [];
  for (const path of paths) {
    const { data: blob } = await supabase.storage.from("progress-photos").download(path);
    if (!blob) continue;
    const buf = new Uint8Array(await blob.arrayBuffer());
    let bin = ""; for (const b of buf) bin += String.fromCharCode(b);
    const mediaType = /\.png$/.test(path) ? "image/png" : /\.webp$/.test(path) ? "image/webp" : "image/jpeg";
    images.push({ base64: btoa(bin), mediaType });
  }
  if (!images.length) return json({ ok: false, error: "needs_photo" });

  const gender = profile.gender as "female" | "male" | "unspecified";
  const heightCm = profile.height_cm as number | null;
  const weightKg = (bw?.weight_kg as number | null) ?? null;
  const goalNote = (profile.goal_note as string | null) ?? null;

  const stats = [heightCm ? `${heightCm} cm tall` : null, weightKg ? `${weightKg} kg` : null]
    .filter(Boolean).join(", ");
  const goalLine = goalNote
    ? `Their stated dream focus: "${goalNote}". Weigh this in the focus areas and advice.`
    : "They have no specific stated goal beyond the aesthetic above.";
  const userText = `Here ${images.length === 1 ? "is my latest progress photo" : `are my ${images.length} latest progress photos`}.${stats ? ` I'm ${stats}.` : ""} ${goalLine}

Give me my fitness report. Reply with ONLY a JSON object matching this shape, no prose:
{"assessable":bool,"overall_score":number,"level":string,"next_level":string,"metrics":[{"key":one of ${METRIC_KEYS.join("|")},"label":string,"score":number,"comment":string}],"strengths":[string],"focus_areas":[string],"focus_muscles":[subset of ${FOCUS_MUSCLES.join("|")}],"summary":string,"next_level_advice":string}`;

  const system = `You are an experienced, supportive strength and physique coach giving a member a progress check from their training photos.

Assess TRAINING DEVELOPMENT only — muscular development, conditioning, symmetry and proportion. Never comment on attractiveness, worth, or anything outside training. Keep any body-fat read as a gentle visual range, never a precise medical figure. This is fitness coaching, not medical advice. Be honest and specific so the scores are useful, but always kind and motivating — this person is showing up.

Their aesthetic goal: ${aestheticTarget(gender)}

Score each axis 0–10 against that goal, where 0–2 = just starting, 3–4 = developing, 5–6 = fit and healthy, 7–8 = athletic and sculpted, 9–10 = elite/stage-ready. Calibrate honestly; most people land 3–7.

Score these six axes (use exactly these keys):
- conditioning: overall leanness and definition
- core: midsection development and definition
- upper: shoulders, chest and back (V-taper for the male goal; toned shoulders/back for the female goal)
- lower: glutes and legs
- arms: arm development
- proportion: posture, symmetry and balance head to toe

If the photos do not clearly show the body (face-only selfie, heavy clothing, bad framing), set assessable=false, set scores to 0, and use the summary to ask for a clear, well-lit training photo.

For focus_muscles, pick the 1–3 app muscle groups whose training would most move the weak points, from: ${FOCUS_MUSCLES.join(", ")}.`;

  let raw: Record<string, unknown>;
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 2048, system,
        messages: [{
          role: "user",
          content: [
            ...images.map((img) => ({
              type: "image", source: { type: "base64", media_type: img.mediaType, data: img.base64 },
            })),
            { type: "text", text: userText },
          ],
        }],
      }),
    });
    if (!res.ok) return json({ ok: false, error: "analysis_failed", detail: await res.text() }, 200);
    const body = await res.json();
    const text = (body.content ?? [])
      .filter((b: { type: string }) => b.type === "text")
      .map((b: { text: string }) => b.text).join("");
    raw = JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
  } catch (e) {
    return json({ ok: false, error: "analysis_failed", detail: String(e) });
  }

  const result = normalize(raw);
  const { data: report, error } = await supabase.from("fitness_reports").insert({
    user_id: user.id,
    assessable: result.assessable, overall_score: result.overall_score,
    level: result.level, next_level: result.next_level, metrics: result.metrics,
    strengths: result.strengths, focus_areas: result.focus_areas,
    focus_muscles: result.focus_muscles, summary: result.summary,
    next_level_advice: result.next_level_advice, body_weight_kg: weightKg,
    photo_count: images.length, model: MODEL,
  }).select("id").single();

  if (error || !report) return json({ ok: false, error: "save_failed" });
  return json({ ok: true, reportId: report.id });
});

function aestheticTarget(gender: string): string {
  if (gender === "male")
    return "Athletic and strong: a clear V-taper (broad shoulders, fuller chest and back, tighter waist), visible core, developed arms, and athletic legs. Lean and muscular, not bulky.";
  if (gender === "female")
    return "Lean, toned and sculpted — the 'Alo yoga' aesthetic: defined but not bulky shoulders and back, a tight midsection, firm rounded glutes, lean legs, and graceful overall proportion at a low-to-moderate body fat.";
  return "A balanced athletic, lean and toned physique with even development head to toe.";
}

function clamp10(n: unknown): number {
  const v = typeof n === "number" && Number.isFinite(n) ? n : 0;
  return Math.max(0, Math.min(10, Math.round(v * 10) / 10));
}

// Mirror of normalizePhysiqueResult — clamp scores, drop unknown keys, bound strings.
function normalize(raw: Record<string, unknown>) {
  const arr = (v: unknown) => (Array.isArray(v) ? v : []);
  const str = (v: unknown, n: number) => String(v ?? "").slice(0, n);
  return {
    assessable: !!raw.assessable,
    overall_score: clamp10(raw.overall_score),
    level: str(raw.level, 40),
    next_level: str(raw.next_level, 40),
    metrics: arr(raw.metrics)
      .filter((m: { key?: string }) => METRIC_KEYS.includes(m?.key ?? ""))
      .map((m: { key: string; label?: unknown; score?: unknown; comment?: unknown }) => ({
        key: m.key, label: str(m.label, 60), score: clamp10(m.score), comment: str(m.comment, 300),
      })),
    strengths: arr(raw.strengths).slice(0, 5).map((s: unknown) => str(s, 200)),
    focus_areas: arr(raw.focus_areas).slice(0, 5).map((s: unknown) => str(s, 200)),
    focus_muscles: arr(raw.focus_muscles).filter((m: unknown) => FOCUS_MUSCLES.includes(m as string)).slice(0, 3),
    summary: str(raw.summary, 600),
    next_level_advice: str(raw.next_level_advice, 600),
  };
}
