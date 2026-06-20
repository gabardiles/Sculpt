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

// The Start-Over wizard's answers, and the program shape Claude returns.
type Brief = {
  goal?: string;        // build muscle | lose fat | get stronger | sport | general
  route?: string;       // "Padel", "Gym — Hypertrophy", "Boxing", …
  sport?: string;       // free-text sport when route is a sport
  daysPerWeek?: number; // 2–6
  sessionMinutes?: number;
  equipment?: string;   // full gym | home | minimal
  level?: string;       // new | some | experienced
  // Tolerate snake_case too, in case a client encoder converts keys.
  days_per_week?: number;
  session_minutes?: number;
};

const briefDays = (b: Brief | null) => b?.daysPerWeek ?? b?.days_per_week;
const briefMinutes = (b: Brief | null) => b?.sessionMinutes ?? b?.session_minutes;
type GenExercise = { name: string; muscle?: string; sets?: number; reps?: string; note?: string };
type GenDay = { name: string; session_type?: string; focus?: string; exercises: GenExercise[] };
type GenProgram = { name: string; summary?: string; days: GenDay[] };

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

  let payload: {
    mode?: string;
    goalNote?: string;
    equipment?: string;
    brief?: Brief;
    program?: GenProgram;
  } = {};
  try { payload = (await req.json()) ?? {}; } catch { /* empty body → defaults */ }
  const MODES = ["insights", "plan", "program", "program_commit"];
  const mode = MODES.includes(payload.mode ?? "") ? payload.mode! : "insights";

  // --- program_commit: persist an approved generated program (no Claude). ----
  // The plan was previewed client-side; here we re-validate every exercise name
  // against the real library, archive the current program, and write the new one
  // as the active program. A fresh program has no logs, so the cycle engine
  // derives it straight to Week 1 / Day 1.
  if (mode === "program_commit") {
    if (!payload.program) return json({ ok: false, error: "no_program" }, 400);
    const programId = await commitProgram(supabase, user.id, payload.program, payload.brief ?? null);
    if (!programId) return json({ ok: false, error: "commit_failed" });
    return json({ ok: true, mode, programId });
  }

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

  // For plan/program modes, give Claude the real exercise library so it picks
  // valid moves (names are re-validated against the library on commit).
  let library = "";
  if (mode === "plan" || mode === "program") {
    const { data: ex } = await supabase.from("exercises")
      .select("name, muscle_group, equipment").order("muscle_group").limit(200);
    library = (ex ?? [])
      .map((e: { name: string; muscle_group: string; equipment: string | null }) =>
        `${e.name} (${e.muscle_group}${e.equipment ? `, ${e.equipment}` : ""})`)
      .join("; ");
  }

  const { system, userText } = mode === "plan"
    ? planPrompt(summary, library, payload.goalNote ?? null, payload.equipment ?? null)
    : mode === "program"
    ? programPrompt(summary, library, payload.brief ?? null)
    : insightsPrompt(summary);

  let raw: Record<string, unknown>;
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: mode === "program" ? 4096 : mode === "plan" ? 2048 : 1024,
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

  const result = mode === "plan" ? normalizePlan(raw)
    : mode === "program" ? normalizeProgram(raw)
    : normalizeInsights(raw);
  return json({ ok: true, mode, result });
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

function programPrompt(summary: string, library: string, brief: Brief | null) {
  const days = Math.max(2, Math.min(6, Math.round(briefDays(brief) ?? 4)));
  const system = `You are an elite strength & conditioning coach. Build a GYM training program — the strength, power and conditioning work done in the weight room. If a sport is named, the program is the S&C that makes the athlete BETTER at that sport (you are NOT scheduling the sport itself): train the qualities that sport demands (e.g. boxing → rotational power, posterior-chain explosiveness, shoulder durability, conditioning; padel/tennis → lateral power, deceleration, rotational core, shoulder care; BJJ → grip, isometric strength, hip power; football → sprint/jump power, hamstrings, single-leg strength). For pure gym goals, build for the stated aesthetic/strength goal.

The program is a repeating ${days}-day weekly split that the app progresses over a 3-week cycle (the app handles the light→medium→hard wave, so give sensible working ranges, not maxes). Day 1 should open with a light calibration feel so the athlete can find starting loads.

Reply with ONLY a JSON object, no prose:
{"name":string,"summary":string,"days":[{"name":string,"session_type":"strength"|"conditioning","focus":string,"exercises":[{"name":string,"muscle":string,"sets":int,"reps":string,"note":string}]}]}
- Exactly ${days} days, each a distinct session (e.g. "Lower Power", "Upper Push", "Conditioning").
- 5–7 exercises per day, ordered big→small. reps is a string like "5", "6–8" or "40s". note: one short cue or load hint.
- Choose exercise names ONLY from the provided library, matching names EXACTLY.
- name: a short, motivating program title that reflects the route/sport.`;
  const b = brief ?? {};
  const briefLine = [
    b.goal ? `Goal: ${b.goal}.` : "",
    b.route ? `Route: ${b.route}.` : "",
    b.sport ? `Sport: ${b.sport}.` : "",
    `Days per week: ${days}.`,
    briefMinutes(b) ? `Session length: ~${briefMinutes(b)} min.` : "",
    b.equipment ? `Equipment: ${b.equipment}.` : "Equipment: full gym.",
    b.level ? `Experience: ${b.level}.` : "",
  ].filter(Boolean).join(" ");
  const dataLine = summary.includes("No logged sessions")
    ? "This is a fresh start — no recent training history."
    : `Recent training for context (don't over-fit to it, this is a fresh program):\n${summary}`;
  const userText = `${briefLine}\n\n${dataLine}\n\nExercise library (use exact names): ${library || "(none — use common barbell/dumbbell movements)"}\n\nBuild my program as the JSON above.`;
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

function normalizeProgram(raw: Record<string, unknown>): GenProgram {
  const days = arr(raw.days).slice(0, 6).map((d: Record<string, unknown>) => ({
    name: str(d.name, 60) || "Session",
    session_type: d.session_type === "conditioning" ? "conditioning" : "strength",
    focus: str(d.focus, 120),
    exercises: arr(d.exercises).slice(0, 8).map((e: Record<string, unknown>) => ({
      name: str(e.name, 80),
      muscle: str(e.muscle, 40),
      sets: int(e.sets, 1, 8),
      reps: str(e.reps, 20),
      note: str(e.note, 160),
    })).filter((e: GenExercise) => e.name.length > 0),
  })).filter((d: GenDay) => d.exercises.length > 0);
  return { name: str(raw.name, 80) || "My Program", summary: str(raw.summary, 200), days };
}

// ---------------------------------------------------------------------------
// Commit — turn an approved generated program into real rows. Re-validates
// every exercise name against the library, archives the current program, and
// writes the new one as active. Uses the caller's RLS-scoped client.
// ---------------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
async function commitProgram(supabase: any, userId: string, program: GenProgram, brief: Brief | null): Promise<string | null> {
  const clean = normalizeProgram(program as unknown as Record<string, unknown>);
  if (!clean.days.length) return null;

  // Map exercise names → library ids (case-insensitive exact match).
  const { data: lib } = await supabase.from("exercises").select("id, name");
  const byName = new Map<string, string>();
  for (const e of (lib ?? []) as { id: string; name: string }[]) byName.set(e.name.trim().toLowerCase(), e.id);

  // Archive whatever is currently active.
  await supabase.from("programs").update({ active: false }).eq("user_id", userId).eq("active", true);

  const { data: created } = await supabase.from("programs").insert({
    user_id: userId,
    name: clean.name,
    weeks: 3,
    days_per_week: clean.days.length,
    active: true,
    schedule_mode: "cycle",
    source: "ai",
    brief: brief ?? null,
  }).select("id").single();
  if (!created) return null;

  let dayIndex = 1;
  for (const day of clean.days) {
    const { data: newDay } = await supabase.from("program_days").insert({
      program_id: created.id,
      day_index: dayIndex++,
      name: day.name,
      week_index: null,
      weekday: null,
      session_type: day.session_type,
      content: day.focus || null,
    }).select("id").single();
    if (!newDay) continue;

    let sort = 0;
    const rows = [];
    for (const ex of day.exercises) {
      const id = byName.get(ex.name.trim().toLowerCase());
      if (!id) continue; // skip anything not in the real library
      const scheme = [ex.reps, ex.note].filter(Boolean).join(" · ").slice(0, 200) || null;
      rows.push({ program_day_id: newDay.id, exercise_id: id, sort: sort++, sets: ex.sets, scheme });
    }
    if (rows.length) await supabase.from("program_exercises").insert(rows);
  }
  return created.id as string;
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
