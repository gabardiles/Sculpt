// Supabase Edge Function: coach
// -----------------------------------------------------------------------------
// Claude-powered training assistant. Two modes, both called from the iOS app
// (and reusable from web) via functions.invoke with the member's auth token, so
// RLS scopes every read to her own rows:
//
//   { "mode": "insights" }                     → plain-language progress insights
//   { "mode": "plan", "goalNote": "...",       → a suggested workout the app can
//     "equipment": "full gym" | "home" | ... }   show and let her apply
//
// The API key never leaves the server. Mirrors fitness-report's call shape.
//
// Deploy:  supabase functions deploy coach
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...   (already set for fitness-report)
// (SUPABASE_URL + SUPABASE_ANON_KEY are present in the function env by default.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "claude-opus-4-8";
const MUSCLES = ["glutes", "hamstrings", "quads", "back", "chest", "shoulders", "arms", "core", "calves"];

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

  let payload: { mode?: string; goalNote?: string; equipment?: string } = {};
  try { payload = (await req.json()) ?? {}; } catch { /* empty body → defaults */ }
  const mode = payload.mode === "plan" ? "plan" : "insights";

  // --- Gather a compact training picture (last ~12 weeks / 25 sessions). ---
  const since = new Date(Date.now() - 84 * 864e5).toISOString();
  const [{ data: logs }, { data: sets }, { data: weights }, { data: goals }] = await Promise.all([
    supabase.from("workout_logs")
      .select("completed_at, week_phase, feel_rating, program_day:program_days(name)")
      .eq("user_id", user.id).gte("completed_at", since)
      .order("completed_at", { ascending: false }).limit(25),
    supabase.from("set_logs")
      .select("weight_kg, reps, sets, exercise:exercises(name, muscle_group, unit), workout_log:workout_logs!inner(user_id, completed_at)")
      .eq("workout_log.user_id", user.id).gte("workout_log.completed_at", since).limit(400),
    supabase.from("body_weight")
      .select("date, weight_kg").eq("user_id", user.id)
      .order("date", { ascending: false }).limit(12),
    supabase.from("goals")
      .select("type, target_value, baseline_value, deadline, achieved, exercise:exercises(name)")
      .eq("user_id", user.id).eq("achieved", false).limit(10),
  ]);

  const summary = buildSummary(logs ?? [], sets ?? [], weights ?? [], goals ?? []);
  if (mode === "insights" && (logs ?? []).length === 0 && (weights ?? []).length === 0) {
    return json({ ok: false, error: "needs_data" });
  }

  // For plan mode, give Claude the real exercise library so it picks valid moves.
  let library = "";
  if (mode === "plan") {
    const { data: ex } = await supabase.from("exercises")
      .select("name, muscle_group, equipment").order("muscle_group").limit(200);
    library = (ex ?? [])
      .map((e: { name: string; muscle_group: string; equipment: string | null }) =>
        `${e.name} (${e.muscle_group}${e.equipment ? `, ${e.equipment}` : ""})`)
      .join("; ");
  }

  const { system, userText } = mode === "plan"
    ? planPrompt(summary, library, payload.goalNote ?? null, payload.equipment ?? null)
    : insightsPrompt(summary);

  let raw: Record<string, unknown>;
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: mode === "plan" ? 2048 : 1024,
        system,
        messages: [{ role: "user", content: [{ type: "text", text: userText }] }],
      }),
    });
    if (!res.ok) return json({ ok: false, error: "generation_failed", detail: await res.text() });
    const body = await res.json();
    const text = (body.content ?? [])
      .filter((b: { type: string }) => b.type === "text")
      .map((b: { text: string }) => b.text).join("");
    raw = JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
  } catch (e) {
    return json({ ok: false, error: "generation_failed", detail: String(e) });
  }

  return json({ ok: true, mode, result: mode === "plan" ? normalizePlan(raw) : normalizeInsights(raw) });
});

// ---------------------------------------------------------------------------
// Data → compact text the model can reason over (keeps the prompt small).
// ---------------------------------------------------------------------------
type Log = { completed_at: string; week_phase: string; feel_rating: number | null; program_day: { name: string } | null };
type Set = { weight_kg: number | null; reps: number | null; sets: number | null; exercise: { name: string; muscle_group: string; unit: string } | null };
type Weight = { date: string; weight_kg: number };
type Goal = { type: string; target_value: number; baseline_value: number | null; deadline: string | null; exercise: { name: string } | null };

function buildSummary(logs: Log[], sets: Set[], weights: Weight[], goals: Goal[]): string {
  const lines: string[] = [];

  // Consistency: sessions in the window + simple weekly cadence.
  const days = logs.map((l) => l.completed_at.slice(0, 10));
  const weeks = new Set(logs.map((l) => isoWeek(l.completed_at)));
  if (logs.length) {
    const feels = logs.map((l) => l.feel_rating).filter((f): f is number => !!f);
    const avgFeel = feels.length ? (feels.reduce((a, b) => a + b, 0) / feels.length).toFixed(1) : "n/a";
    lines.push(`Sessions: ${logs.length} over ${weeks.size} week(s); most recent ${days[0]}. Avg feel rating ${avgFeel}/5.`);
    const byDay = tally(logs.map((l) => l.program_day?.name ?? "Workout"));
    lines.push(`Recent days trained: ${byDay}.`);
  } else {
    lines.push("No logged sessions in the last 12 weeks.");
  }

  // Best top set per exercise (a rough PR view) + muscle coverage.
  const best = new Map<string, { w: number; reps: number; unit: string; muscle: string }>();
  const muscleVol = new Map<string, number>();
  for (const s of sets) {
    const name = s.exercise?.name; if (!name) continue;
    const w = Number(s.weight_kg ?? 0), reps = Number(s.reps ?? 0), setn = Number(s.sets ?? 1);
    muscleVol.set(s.exercise!.muscle_group, (muscleVol.get(s.exercise!.muscle_group) ?? 0) + w * reps * setn);
    const prev = best.get(name);
    if (!prev || w > prev.w) best.set(name, { w, reps, unit: s.exercise!.unit, muscle: s.exercise!.muscle_group });
  }
  if (best.size) {
    const top = [...best.entries()].slice(0, 12)
      .map(([n, b]) => `${n} ${b.w}${b.unit}×${b.reps}`).join("; ");
    lines.push(`Top sets: ${top}.`);
    const cov = [...muscleVol.entries()].sort((a, b) => b[1] - a[1]).map(([m]) => m);
    const missing = MUSCLES.filter((m) => !muscleVol.has(m));
    lines.push(`Most-trained muscles: ${cov.slice(0, 4).join(", ") || "n/a"}.${missing.length ? ` Under-trained / missing: ${missing.join(", ")}.` : ""}`);
  }

  // Body-weight trend.
  if (weights.length >= 2) {
    const newest = weights[0], oldest = weights[weights.length - 1];
    const delta = (newest.weight_kg - oldest.weight_kg).toFixed(1);
    lines.push(`Body weight: ${newest.weight_kg} kg now vs ${oldest.weight_kg} kg on ${oldest.date} (${delta} kg).`);
  } else if (weights.length === 1) {
    lines.push(`Body weight: ${weights[0].weight_kg} kg (single entry).`);
  }

  // Active goals.
  if (goals.length) {
    const g = goals.map((x) => {
      const what = x.type === "exercise_pr" && x.exercise?.name ? `${x.exercise.name} PR` : x.type.replace("_", " ");
      return `${what}→${x.target_value}${x.deadline ? ` by ${x.deadline}` : ""}`;
    }).join("; ");
    lines.push(`Active goals: ${g}.`);
  }

  return lines.join("\n");
}

function insightsPrompt(summary: string) {
  const system = `You are an experienced, supportive strength coach reviewing a member's recent training data. Give honest, specific, encouraging insights — never generic. This is fitness coaching, not medical advice. Ground every point in the data provided; do not invent numbers.

Reply with ONLY a JSON object, no prose:
{"headline":string,"insights":[{"title":string,"detail":string,"tone":"win"|"watch"|"tip"}],"suggestion":string}
- headline: one warm sentence summarizing where they're at.
- insights: 2–4 items. "win" = something going well, "watch" = a gap or risk (e.g. an under-trained muscle, dropping consistency), "tip" = a concrete adjustment.
- suggestion: the single most useful next action this week.`;
  const userText = `Here is my recent training data:\n\n${summary}\n\nGive me my progress insights as the JSON above.`;
  return { system, userText };
}

function planPrompt(summary: string, library: string, goalNote: string | null, equipment: string | null) {
  const system = `You are an experienced strength & physique coach building a single training session for a member, balanced against what they've been doing. Favour their under-trained muscles, respect their goals, and only use real exercises from the provided library (match names exactly). This is fitness coaching, not medical advice.

Reply with ONLY a JSON object, no prose:
{"title":string,"rationale":string,"focus_muscles":[subset of ${MUSCLES.join("|")}],"exercises":[{"name":string,"muscle":string,"sets":int,"reps":string,"note":string}]}
- 5–7 exercises, ordered big→small. reps is a string like "6–8" or "30s". note: one short cue or load hint.
- Choose names ONLY from the library list.`;
  const goalLine = goalNote ? `Their stated goal: "${goalNote}".` : "No extra stated goal beyond their data.";
  const equipLine = equipment ? `Available equipment: ${equipment}.` : "Assume a typical gym.";
  const userText = `My recent training:\n\n${summary}\n\n${goalLine} ${equipLine}\n\nExercise library (use exact names): ${library || "(none provided — use common barbell/dumbbell movements)"}\n\nBuild me today's session as the JSON above.`;
  return { system, userText };
}

// ---------------------------------------------------------------------------
// Normalizers — clamp, bound strings, drop unknowns (mirrors fitness-report).
// ---------------------------------------------------------------------------
const arr = (v: unknown) => (Array.isArray(v) ? v : []);
const str = (v: unknown, n: number) => String(v ?? "").slice(0, n);
const int = (v: unknown, lo: number, hi: number) => {
  const n = Math.round(Number(v)); return Number.isFinite(n) ? Math.max(lo, Math.min(hi, n)) : lo;
};

function normalizeInsights(raw: Record<string, unknown>) {
  const tones = ["win", "watch", "tip"];
  return {
    headline: str(raw.headline, 200),
    insights: arr(raw.insights).slice(0, 4).map((i: { title?: unknown; detail?: unknown; tone?: unknown }) => ({
      title: str(i.title, 80),
      detail: str(i.detail, 300),
      tone: tones.includes(i.tone as string) ? i.tone : "tip",
    })),
    suggestion: str(raw.suggestion, 300),
  };
}

function normalizePlan(raw: Record<string, unknown>) {
  return {
    title: str(raw.title, 80),
    rationale: str(raw.rationale, 400),
    focus_muscles: arr(raw.focus_muscles).filter((m: unknown) => MUSCLES.includes(m as string)).slice(0, 3),
    exercises: arr(raw.exercises).slice(0, 8).map((e: { name?: unknown; muscle?: unknown; sets?: unknown; reps?: unknown; note?: unknown }) => ({
      name: str(e.name, 80),
      muscle: str(e.muscle, 40),
      sets: int(e.sets, 1, 8),
      reps: str(e.reps, 20),
      note: str(e.note, 160),
    })),
  };
}

// --- tiny helpers ---
function isoWeek(iso: string): string {
  const d = new Date(iso); const day = (d.getUTCDay() + 6) % 7;
  d.setUTCDate(d.getUTCDate() - day + 3);
  const firstThu = new Date(Date.UTC(d.getUTCFullYear(), 0, 4));
  const week = 1 + Math.round(((d.getTime() - firstThu.getTime()) / 864e5 - 3 + ((firstThu.getUTCDay() + 6) % 7)) / 7);
  return `${d.getUTCFullYear()}-W${week}`;
}
function tally(items: string[]): string {
  const m = new Map<string, number>();
  for (const i of items) m.set(i, (m.get(i) ?? 0) + 1);
  return [...m.entries()].map(([k, v]) => `${k}×${v}`).join(", ");
}
