"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient, createAdminClient } from "@/lib/supabase/server";
import type { WeekIntensity } from "@/lib/types";

async function requireUserId() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  return { supabase, userId: user.id };
}

// ------------------------------------------------------------- onboarding

type Supa = Awaited<ReturnType<typeof createClient>>;

const TEMPLATE_NAMES = [
  "Lean & Sculpted",
  "Strong & Built",
  "Hybrid Athlete",
] as const;

const GENDERS = ["female", "male", "unspecified"] as const;

async function cloneTemplateProgram(
  supabase: Supa,
  userId: string,
  templateName: string
): Promise<boolean> {
  const { data: template } = await supabase
    .from("programs")
    .select("*, program_weeks(*), program_days(*, program_exercises(*))")
    .is("user_id", null)
    .eq("name", templateName)
    .limit(1)
    .maybeSingle();
  if (!template) return false;

  const { data: program } = await supabase
    .from("programs")
    .insert({
      user_id: userId,
      name: template.name,
      weeks: template.weeks,
      days_per_week: template.days_per_week,
      active: true,
      schedule_mode: template.schedule_mode ?? "cycle",
    })
    .select("id")
    .single();
  if (!program) return false;

  type TemplateWeek = {
    week_index: number;
    intensity: string;
    label: string | null;
    note: string | null;
  };
  const weeks = (template.program_weeks ?? []) as TemplateWeek[];
  if (weeks.length) {
    await supabase.from("program_weeks").insert(
      weeks.map((w) => ({
        program_id: program.id,
        week_index: w.week_index,
        intensity: w.intensity,
        label: w.label,
        note: w.note,
      }))
    );
  }

  type TemplateDay = {
    day_index: number;
    name: string;
    week_index: number | null;
    weekday: number | null;
    session_type: string;
    content: string | null;
    program_exercises: {
      exercise_id: string;
      sort: number;
      sets: number;
      scheme: string | null;
    }[];
  };
  for (const day of (template.program_days ?? []) as TemplateDay[]) {
    const { data: newDay } = await supabase
      .from("program_days")
      .insert({
        program_id: program.id,
        day_index: day.day_index,
        name: day.name,
        week_index: day.week_index,
        weekday: day.weekday,
        session_type: day.session_type ?? "strength",
        content: day.content,
      })
      .select("id")
      .single();
    if (newDay && day.program_exercises?.length) {
      await supabase.from("program_exercises").insert(
        day.program_exercises.map((pe) => ({
          program_day_id: newDay.id,
          exercise_id: pe.exercise_id,
          sort: pe.sort,
          sets: pe.sets,
          scheme: pe.scheme,
        }))
      );
    }
  }
  return true;
}

export interface IntakeAnswers {
  glutes: number;
  strong: number;
  lean: number;
}

/**
 * Deterministic, coach-approved program adjustments — applied ONCE per
 * submit, never per-render. All swaps respect the same-pattern/same-muscle
 * guardrail; compounds are never removed.
 */
async function applyIntakeCore(
  supabase: Supa,
  userId: string,
  answers: IntakeAnswers
): Promise<string[]> {
  const { getActiveProgram } = await import("@/lib/data");
  const program = await getActiveProgram(supabase, userId);
  if (!program) return [];

  const changes: string[] = [];
  const { data: lib } = await supabase
    .from("exercises")
    .select("*")
    .eq("is_global", true);
  type Ex = {
    id: string;
    name: string;
    muscle_group: string;
    movement_pattern: string;
    rep_profile: string;
  };
  const library = (lib ?? []) as Ex[];
  const inProgram = new Set(
    program.days.flatMap((d) => d.exercises.map((pe) => pe.exercise_id))
  );

  // Strong ≥ 4: up to two pump accessories become strength-tier moves,
  // same pattern + muscle, later days first (finishers go heavy).
  if (answers.strong >= 4) {
    let swapped = 0;
    const rows = [...program.days]
      .reverse()
      .flatMap((d) => [...d.exercises].reverse());
    for (const pe of rows) {
      if (swapped >= 2) break;
      if (pe.exercise.rep_profile !== "pump") continue;
      const alt = library.find(
        (e) =>
          !inProgram.has(e.id) &&
          e.rep_profile === "strength" &&
          e.movement_pattern === pe.exercise.movement_pattern &&
          e.muscle_group === pe.exercise.muscle_group
      );
      if (!alt) continue;
      await supabase
        .from("program_exercises")
        .update({ exercise_id: alt.id })
        .eq("id", pe.id);
      inProgram.delete(pe.exercise_id);
      inProgram.add(alt.id);
      changes.push(`${pe.exercise.name} → ${alt.name} (heavier work)`);
      swapped++;
    }
  }

  // Lean upper ≥ 4: one extra upper-body pump accessory on the upper day.
  if (answers.lean >= 4) {
    const upperCount = (d: (typeof program.days)[number]) =>
      d.exercises.filter((pe) =>
        ["push", "pull"].includes(pe.exercise.movement_pattern)
      ).length;
    const upperDay = [...program.days].sort(
      (a, b) => upperCount(b) - upperCount(a)
    )[0];
    if (upperDay && upperDay.exercises.length < 7) {
      const pick = library.find(
        (e) =>
          !inProgram.has(e.id) &&
          e.rep_profile === "pump" &&
          ["shoulders", "arms", "chest", "back"].includes(e.muscle_group)
      );
      if (pick) {
        const nextSort =
          Math.max(0, ...upperDay.exercises.map((x) => x.sort)) + 1;
        await supabase.from("program_exercises").insert({
          program_day_id: upperDay.id,
          exercise_id: pick.id,
          sort: nextSort,
          sets: 3,
        });
        inProgram.add(pick.id);
        changes.push(`Added ${pick.name} to ${upperDay.name}`);
      }
    }
  }

  // Glutes ≤ 2: trim one glute pump from the glute-heaviest day.
  if (answers.glutes <= 2) {
    const glutePumps = (d: (typeof program.days)[number]) =>
      d.exercises.filter(
        (pe) =>
          pe.exercise.muscle_group === "glutes" &&
          pe.exercise.rep_profile === "pump"
      );
    const gluteDay = [...program.days].sort(
      (a, b) => glutePumps(b).length - glutePumps(a).length
    )[0];
    if (gluteDay && gluteDay.exercises.length > 5) {
      const victim = glutePumps(gluteDay).at(-1);
      if (victim) {
        await supabase.from("program_exercises").delete().eq("id", victim.id);
        changes.push(`Removed ${victim.exercise.name} (less glute focus)`);
      }
    }
  }

  await supabase
    .from("programs")
    .update({
      intake: { ...answers, applied_at: new Date().toISOString() },
    })
    .eq("id", program.id)
    .eq("user_id", userId);

  return changes;
}

export async function applyIntake(answers: IntakeAnswers) {
  const { supabase, userId } = await requireUserId();
  const safe: IntakeAnswers = {
    glutes: Math.min(5, Math.max(1, Math.round(answers.glutes))),
    strong: Math.min(5, Math.max(1, Math.round(answers.strong))),
    lean: Math.min(5, Math.max(1, Math.round(answers.lean))),
  };
  const changes = await applyIntakeCore(supabase, userId, safe);
  revalidatePath("/");
  revalidatePath("/program");
  return { ok: true as const, changes };
}

export async function completeOnboarding(formData: FormData) {
  const { supabase, userId } = await requireUserId();
  const name = String(formData.get("name") ?? "").trim();
  if (!name) return;

  // A few data points up front: sex drives the suggested program + theme.
  const sex = String(formData.get("sex") ?? "");
  const gender = GENDERS.includes(sex as (typeof GENDERS)[number])
    ? (sex as (typeof GENDERS)[number])
    : "unspecified";

  const ageN = parseInt(String(formData.get("age") ?? ""), 10);
  const age = Number.isFinite(ageN) && ageN >= 13 && ageN <= 100 ? ageN : null;
  const heightN = parseFloat(String(formData.get("height_cm") ?? "").replace(",", "."));
  const heightCm =
    Number.isFinite(heightN) && heightN >= 120 && heightN <= 230 ? heightN : null;
  const weightN = parseFloat(String(formData.get("weight") ?? "").replace(",", "."));

  // Men get the Spartan look + Strong & Built; women (and unspecified) get
  // the Sculpt dusty-pink look + Lean & Sculpted.
  const theme = gender === "male" ? "spartan" : "sculpt";
  const template = gender === "male" ? "Strong & Built" : "Lean & Sculpted";

  await supabase
    .from("profiles")
    .update({ name, gender, age, height_cm: heightCm, theme })
    .eq("id", userId);

  // Cookie mirror so the very first paint after onboarding is themed.
  const { cookies } = await import("next/headers");
  (await cookies()).set("sculpt-theme", theme, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });

  // Log starting weight to the diary so it feeds trends + the fitness report.
  if (Number.isFinite(weightN) && weightN > 0 && weightN <= 400) {
    const date = new Date().toISOString().slice(0, 10);
    await supabase
      .from("body_weight")
      .upsert({ user_id: userId, date, weight_kg: weightN }, { onConflict: "user_id,date" });
  }

  // Clone the suggested template if they don't have a program yet.
  const { data: existing } = await supabase
    .from("programs")
    .select("id")
    .eq("user_id", userId)
    .eq("active", true)
    .maybeSingle();

  if (!existing) {
    await cloneTemplateProgram(supabase, userId, template);
  }

  revalidatePath("/", "layout");
  redirect("/");
}

// ---------------------------------------------------------------- workout

export interface WorkoutEntry {
  exerciseId: string;
  weightKg: number | null;
  reps: number | null;
  sets: number | null;
}

export async function completeWorkout(input: {
  programDayId: string;
  phase: WeekIntensity;
  cycle: number;
  feel: number;
  entries: WorkoutEntry[];
}) {
  const { supabase, userId } = await requireUserId();

  // PB detection must look at history BEFORE this session is written.
  const weighted = input.entries.filter((e) => e.weightKg != null);
  const prBefore = new Map<string, number>();
  if (weighted.length) {
    const { data: prev } = await supabase
      .from("set_logs")
      .select("exercise_id, weight_kg, workout_log:workout_logs!inner(user_id)")
      .eq("workout_log.user_id", userId)
      .in("exercise_id", weighted.map((e) => e.exerciseId))
      .not("weight_kg", "is", null);
    for (const row of (prev ?? []) as { exercise_id: string; weight_kg: number }[]) {
      const cur = prBefore.get(row.exercise_id) ?? 0;
      if (row.weight_kg > cur) prBefore.set(row.exercise_id, row.weight_kg);
    }
  }

  const { data: log, error } = await supabase
    .from("workout_logs")
    .insert({
      user_id: userId,
      program_day_id: input.programDayId,
      week_phase: input.phase,
      cycle_number: input.cycle,
      feel_rating: input.feel,
    })
    .select("id")
    .single();

  if (error || !log) return { ok: false as const, error: error?.message };

  // Light up today on the Green Days calendar (partial upsert — never clobbers
  // a synced step count). Mirrors Repository.markWorkoutDone on iOS.
  await supabase
    .from("activity_days")
    .upsert(
      { user_id: userId, date: new Date().toISOString().slice(0, 10), workout_done: true },
      { onConflict: "user_id,date" }
    );

  if (input.entries.length) {
    await supabase.from("set_logs").insert(
      input.entries.map((e) => ({
        workout_log_id: log.id,
        exercise_id: e.exerciseId,
        weight_kg: e.weightKg,
        reps: e.reps,
        sets: e.sets,
      }))
    );
  }

  // Share the win with friends — never weights-in-progress or body data,
  // just "she showed up" and any new PBs.
  const { data: day } = await supabase
    .from("program_days")
    .select("name")
    .eq("id", input.programDayId)
    .maybeSingle();

  const feedRows: {
    user_id: string;
    type: string;
    body: string;
    metadata: Record<string, unknown>;
  }[] = [
    {
      user_id: userId,
      type: "workout",
      body: `Completed ${day?.name ?? "a workout"}`,
      metadata: {
        day_name: day?.name ?? null,
        phase: input.phase,
        cycle: input.cycle,
        exercises: input.entries.length,
      },
    },
  ];

  const pbEntries = weighted.filter((e) => {
    const before = prBefore.get(e.exerciseId);
    return before != null && e.weightKg! > before;
  });
  if (pbEntries.length) {
    const { data: exNames } = await supabase
      .from("exercises")
      .select("id, name, unit")
      .in("id", pbEntries.map((e) => e.exerciseId));
    const nameById = new Map(
      ((exNames ?? []) as { id: string; name: string; unit: string }[]).map((e) => [
        e.id,
        e,
      ])
    );
    for (const e of pbEntries) {
      const ex = nameById.get(e.exerciseId);
      if (!ex || ex.unit !== "kg") continue;
      feedRows.push({
        user_id: userId,
        type: "pb",
        body: `New PB — ${ex.name} ${e.weightKg} kg`,
        metadata: { exercise_id: e.exerciseId, exercise_name: ex.name, weight_kg: e.weightKg },
      });
    }
  }

  await supabase.from("feed_posts").insert(feedRows);

  revalidatePath("/");
  revalidatePath("/program");
  revalidatePath("/friends");
  return { ok: true as const };
}

// ----------------------------------------------------------------- friends

export async function addFriendByCode(formData: FormData) {
  const { supabase } = await requireUserId();
  const code = String(formData.get("code") ?? "").trim();
  if (!code) return { ok: false as const, error: "Enter a code." };
  const { data, error } = await supabase.rpc("add_friend", { code });
  if (error) return { ok: false as const, error: error.message };
  const result = data as { ok: boolean; error?: string };
  if (!result.ok) return { ok: false as const, error: result.error ?? "Couldn't add." };
  revalidatePath("/friends");
  return { ok: true as const };
}

export async function removeFriend(friendId: string) {
  const { supabase, userId } = await requireUserId();
  // friendId goes into a PostgREST filter string — accept UUIDs only.
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(friendId)) {
    return;
  }
  // Both directions — the delete policy allows removing either side.
  await supabase
    .from("friends")
    .delete()
    .or(
      `and(user_id.eq.${userId},friend_id.eq.${friendId}),and(user_id.eq.${friendId},friend_id.eq.${userId})`
    );
  revalidatePath("/friends");
}

export async function createFeedPost(input: {
  type: "photo" | "message";
  body: string | null;
  storagePath: string | null;
}) {
  const { supabase, userId } = await requireUserId();
  const body = input.body?.trim() || null;
  if (input.type === "message" && !body) return;
  if (input.type === "photo" && !input.storagePath) return;
  await supabase.from("feed_posts").insert({
    user_id: userId,
    type: input.type,
    body,
    storage_path: input.storagePath,
  });
  revalidatePath("/friends");
}

export async function deleteFeedPost(postId: string, storagePath: string | null) {
  const { supabase } = await requireUserId();
  await supabase.from("feed_posts").delete().eq("id", postId);
  if (storagePath) {
    await supabase.storage.from("feed-photos").remove([storagePath]);
  }
  revalidatePath("/friends");
}

export async function toggleCheer(postId: string, on: boolean) {
  const { supabase, userId } = await requireUserId();
  if (on) {
    await supabase
      .from("feed_cheers")
      .upsert({ post_id: postId, user_id: userId }, { onConflict: "post_id,user_id" });
  } else {
    await supabase
      .from("feed_cheers")
      .delete()
      .eq("post_id", postId)
      .eq("user_id", userId);
  }
  revalidatePath("/friends");
}

export async function addComment(postId: string, body: string) {
  const { supabase, userId } = await requireUserId();
  const text = body.trim().slice(0, 280);
  if (!text) return { ok: false as const };
  // RLS rejects comments on posts the caller can't see.
  const { error } = await supabase
    .from("feed_comments")
    .insert({ post_id: postId, user_id: userId, body: text });
  if (error) return { ok: false as const };
  revalidatePath("/friends");
  return { ok: true as const };
}

export async function deleteComment(commentId: string) {
  const { supabase } = await requireUserId();
  await supabase.from("feed_comments").delete().eq("id", commentId);
  revalidatePath("/friends");
}

// ---------------------------------------------------------------- program

/** Close the current week from 3/5 sessions — checkbox week, on to the next.
 *  Fixed-schedule programs pass week_index as cycle, intensity as phase. */
export async function closeWeek(cycle: number, phase: WeekIntensity) {
  const { supabase, userId } = await requireUserId();
  await supabase
    .from("week_closures")
    .upsert(
      { user_id: userId, cycle_number: cycle, week_phase: phase },
      { onConflict: "user_id,cycle_number,week_phase" }
    );
  revalidatePath("/");
  revalidatePath("/program");
}

export async function resetCycle(programId: string, nextCycle: number) {
  const { supabase, userId } = await requireUserId();
  await supabase
    .from("programs")
    .update({ cycle_floor: nextCycle })
    .eq("id", programId)
    .eq("user_id", userId);
  revalidatePath("/");
  revalidatePath("/program");
}

const MUSCLE_GROUPS = [
  "glutes",
  "hamstrings",
  "quads",
  "back",
  "chest",
  "shoulders",
  "arms",
  "core",
  "calves",
];
const PATTERNS = [
  "hinge",
  "squat",
  "lunge",
  "thrust",
  "abduction",
  "push",
  "pull",
  "core",
  "accessory",
];
const PROFILES = ["strength", "pump", "timed"];

/** Accepts watch/share/shorts/embed YouTube links → privacy embed URL. */
function toEmbedUrl(input: string): string | null {
  const m = input.match(
    /(?:youtube(?:-nocookie)?\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]{11})/
  );
  return m ? `https://www.youtube-nocookie.com/embed/${m[1]}` : null;
}

/** A user's own exercise — private to her, joins the swap/add pools. */
export async function createCustomExercise(formData: FormData) {
  const { supabase, userId } = await requireUserId();

  const name = String(formData.get("name") ?? "").trim().slice(0, 60);
  const muscle = String(formData.get("muscle_group") ?? "");
  const pattern = String(formData.get("movement_pattern") ?? "");
  const profile = String(formData.get("rep_profile") ?? "");
  const equipment =
    String(formData.get("equipment") ?? "").trim().slice(0, 40) || null;
  const video = String(formData.get("video_url") ?? "").trim();

  if (name.length < 2) return { ok: false as const, error: "Give it a name." };
  if (!MUSCLE_GROUPS.includes(muscle) || !PATTERNS.includes(pattern)) {
    return { ok: false as const, error: "Pick a muscle and a movement." };
  }
  if (!PROFILES.includes(profile)) {
    return { ok: false as const, error: "Pick a training role." };
  }
  let instructionUrl: string | null = null;
  if (video) {
    instructionUrl = toEmbedUrl(video);
    if (!instructionUrl) {
      return {
        ok: false as const,
        error: "Couldn't read that YouTube link — paste the video's URL.",
      };
    }
  }

  const { error } = await supabase.from("exercises").insert({
    name,
    muscle_group: muscle,
    movement_pattern: pattern,
    rep_profile: profile,
    unit: profile === "timed" ? "s" : "kg",
    equipment,
    instruction_url: instructionUrl,
    is_global: false,
    created_by: userId,
  });
  if (error) return { ok: false as const, error: "Couldn't save — try again." };

  revalidatePath("/program");
  return { ok: true as const };
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Edit one of your own custom exercises. RLS blocks touching the library. */
export async function updateCustomExercise(formData: FormData) {
  const { supabase } = await requireUserId();

  const id = String(formData.get("id") ?? "");
  if (!UUID_RE.test(id)) return { ok: false as const, error: "Unknown exercise." };

  const name = String(formData.get("name") ?? "").trim().slice(0, 60);
  const muscle = String(formData.get("muscle_group") ?? "");
  const pattern = String(formData.get("movement_pattern") ?? "");
  const profile = String(formData.get("rep_profile") ?? "");
  const equipment =
    String(formData.get("equipment") ?? "").trim().slice(0, 40) || null;
  const video = String(formData.get("video_url") ?? "").trim();

  if (name.length < 2) return { ok: false as const, error: "Give it a name." };
  if (!MUSCLE_GROUPS.includes(muscle) || !PATTERNS.includes(pattern)) {
    return { ok: false as const, error: "Pick a muscle and a movement." };
  }
  if (!PROFILES.includes(profile)) {
    return { ok: false as const, error: "Pick a training role." };
  }
  let instructionUrl: string | null = null;
  if (video) {
    instructionUrl = toEmbedUrl(video);
    if (!instructionUrl) {
      return {
        ok: false as const,
        error: "Couldn't read that YouTube link — paste the video's URL.",
      };
    }
  }

  // RLS ("exercises update own") limits this to the caller's non-global rows.
  const { error } = await supabase
    .from("exercises")
    .update({
      name,
      muscle_group: muscle,
      movement_pattern: pattern,
      rep_profile: profile,
      unit: profile === "timed" ? "s" : "kg",
      equipment,
      instruction_url: instructionUrl,
    })
    .eq("id", id)
    .eq("is_global", false);
  if (error) return { ok: false as const, error: "Couldn't save — try again." };

  revalidatePath("/program");
  return { ok: true as const };
}

/**
 * Delete one of your own custom exercises. It's first pulled from your
 * program; if it has logged history (set_logs FK) it can't be removed
 * without destroying that history, so we keep it and say so.
 */
export async function deleteCustomExercise(exerciseId: string) {
  const { supabase } = await requireUserId();
  if (!UUID_RE.test(exerciseId)) {
    return { ok: false as const, error: "Unknown exercise." };
  }

  // If it was ever logged, deleting would orphan history — refuse cleanly.
  const { count } = await supabase
    .from("set_logs")
    .select("id", { count: "exact", head: true })
    .eq("exercise_id", exerciseId);
  if ((count ?? 0) > 0) {
    return {
      ok: false as const,
      error: "You've logged this one — edit it instead, so your history stays.",
    };
  }

  // Pull it out of the program (RLS limits to the caller's own rows), then
  // delete the exercise itself (RLS limits to the caller's non-global rows).
  await supabase.from("program_exercises").delete().eq("exercise_id", exerciseId);
  const { error } = await supabase
    .from("exercises")
    .delete()
    .eq("id", exerciseId)
    .eq("is_global", false);
  if (error) return { ok: false as const, error: "Couldn't delete — try again." };

  revalidatePath("/program");
  return { ok: true as const };
}

export async function swapExercise(programExerciseId: string, newExerciseId: string) {
  const { supabase } = await requireUserId();
  // RLS guarantees she can only touch rows in her own program.
  await supabase
    .from("program_exercises")
    .update({ exercise_id: newExerciseId })
    .eq("id", programExerciseId);
  revalidatePath("/program");
}

export async function removeExercise(programExerciseId: string) {
  const { supabase } = await requireUserId();
  await supabase.from("program_exercises").delete().eq("id", programExerciseId);
  revalidatePath("/program");
}

export async function addExercise(programDayId: string, exerciseId: string, sort: number) {
  const { supabase } = await requireUserId();
  await supabase
    .from("program_exercises")
    .insert({ program_day_id: programDayId, exercise_id: exerciseId, sort, sets: 3 });
  revalidatePath("/program");
}

// ----------------------------------------------------------- weight diary

export async function logBodyWeight(formData: FormData) {
  const { supabase, userId } = await requireUserId();
  const weight = parseFloat(String(formData.get("weight") ?? "").replace(",", "."));
  if (!Number.isFinite(weight) || weight <= 0 || weight > 400) return;
  const date = String(formData.get("date") ?? "") || new Date().toISOString().slice(0, 10);

  await supabase
    .from("body_weight")
    .upsert({ user_id: userId, date, weight_kg: weight }, { onConflict: "user_id,date" });
  revalidatePath("/weight");
  revalidatePath("/");
}

// ------------------------------------------------------------------ goals

export async function createGoal(formData: FormData) {
  const { supabase, userId } = await requireUserId();

  const { count } = await supabase
    .from("goals")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("achieved", false);
  if ((count ?? 0) >= 3) return; // max 3 active goals

  const type = String(formData.get("type"));
  if (!["body_weight", "exercise_pr", "consistency", "fitness_score"].includes(type)) return;
  const target = parseFloat(String(formData.get("target") ?? "").replace(",", "."));
  if (!Number.isFinite(target) || target <= 0) return;
  // A fitness score lives on a 0–10 scale.
  if (type === "fitness_score" && target > 10) return;
  const exerciseId = String(formData.get("exercise_id") ?? "") || null;
  const deadline = String(formData.get("deadline") ?? "") || null;
  if (type === "exercise_pr" && !exerciseId) return;

  let baseline: number | null = null;
  if (type === "body_weight") {
    const { data } = await supabase
      .from("body_weight")
      .select("weight_kg")
      .eq("user_id", userId)
      .order("date", { ascending: false })
      .limit(1)
      .maybeSingle();
    baseline = data?.weight_kg ?? null;
  } else if (type === "fitness_score") {
    const { data } = await supabase
      .from("fitness_reports")
      .select("overall_score")
      .eq("user_id", userId)
      .eq("assessable", true)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    baseline = (data?.overall_score as number | null) ?? null;
  }

  await supabase.from("goals").insert({
    user_id: userId,
    type,
    target_value: target,
    baseline_value: baseline,
    exercise_id: type === "exercise_pr" ? exerciseId : null,
    deadline,
  });
  revalidatePath("/goals");
  revalidatePath("/");
}

export async function deleteGoal(goalId: string) {
  const { supabase } = await requireUserId();
  await supabase.from("goals").delete().eq("id", goalId);
  revalidatePath("/goals");
  revalidatePath("/");
}

export async function markGoalAchieved(goalId: string) {
  const { supabase } = await requireUserId();
  await supabase
    .from("goals")
    .update({ achieved: true, achieved_at: new Date().toISOString() })
    .eq("id", goalId);
  revalidatePath("/goals");
  revalidatePath("/");
}

// ------------------------------------------------------------------ photos

export async function recordProgressPhoto(input: {
  cycle: number;
  weekLabel: string;
  storagePath: string;
}) {
  const { supabase, userId } = await requireUserId();
  await supabase.from("progress_photos").insert({
    user_id: userId,
    cycle_number: input.cycle,
    week_label: input.weekLabel,
    storage_path: input.storagePath,
  });
  revalidatePath("/photos");
}

export async function deleteProgressPhoto(photoId: string, storagePath: string) {
  const { supabase } = await requireUserId();
  await supabase.from("progress_photos").delete().eq("id", photoId);
  await supabase.storage.from("progress-photos").remove([storagePath]);
  revalidatePath("/photos");
}

// ------------------------------------------------------------------- admin

export async function inviteUser(formData: FormData) {
  const { supabase, userId } = await requireUserId();

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", userId)
    .maybeSingle();
  if (!profile?.is_admin) return { ok: false as const, error: "Not allowed." };

  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return { ok: false as const, error: "That doesn't look like an email." };
  }

  // 1. Create the account directly — active and auto-approved immediately
  //    (email_confirm: true), no password. Login is by emailed 6-digit code,
  //    so nothing depends on redirect-URL configuration.
  const admin = createAdminClient();
  const { error: createError } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    user_metadata: { invited_by: userId },
  });
  const alreadyExisted =
    !!createError && createError.message.toLowerCase().includes("already");
  if (createError && !alreadyExisted) {
    return { ok: false as const, error: createError.message };
  }

  // 2. Email her. createUser() on its own sends nothing — that's why
  //    earlier invites arrived silently (no email at all). Prefer a branded
  //    Resend invite when configured; otherwise fall back to Supabase's own
  //    mailer with the same sign-in code she'd request at login. Both are
  //    best-effort: the admin UI always offers a copyable invite message.
  let emailSent = false;
  const resendKey = process.env.RESEND_API_KEY;
  const resendFrom = process.env.RESEND_FROM;
  if (resendKey && resendFrom) {
    const site =
      process.env.NEXT_PUBLIC_SITE_URL ??
      "https://sculpt-gabardiles-projects.vercel.app";
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: `Sculpt <${resendFrom}>`,
          to: email,
          subject: "You're invited to Sculpt",
          html: `
<div style="font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;max-width:420px;margin:0 auto;padding:32px 24px;color:#2B2422;background:#FBF7F6;border-radius:24px">
  <p style="font-size:11px;letter-spacing:2px;color:#6F635E;margin:0">TRAINING TRACKER</p>
  <h1 style="font-weight:300;letter-spacing:4px;margin:8px 0 24px">SCULPT</h1>
  <p style="font-size:15px;line-height:1.6;font-weight:300">
    You've been invited. Your account is ready — no password, ever.
  </p>
  <ol style="font-size:14px;line-height:1.9;font-weight:300;padding-left:20px">
    <li>Open <a href="${site}" style="color:#B97D77">${site.replace("https://", "")}</a></li>
    <li>Sign in with <strong>${email}</strong></li>
    <li>A 6-digit code lands here — type it in, and you're training</li>
  </ol>
  <p style="font-size:13px;line-height:1.6;color:#6F635E;font-weight:300">
    Tip: install it like an app — You&nbsp;→&nbsp;Install on your phone.
  </p>
</div>`,
        }),
      });
      emailSent = res.ok;
    } catch {
      emailSent = false;
    }
  } else {
    const { error: sendError } = await supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: false },
    });
    emailSent = !sendError;
  }

  return { ok: true as const, emailSent };
}

// ------------------------------------------------------------------- theme

export async function setTheme(theme: "sculpt" | "spartan") {
  const { supabase, userId } = await requireUserId();
  if (theme !== "sculpt" && theme !== "spartan") return;
  await supabase.from("profiles").update({ theme }).eq("id", userId);
  // Cookie mirror: the layout reads this with zero network cost.
  const { cookies } = await import("next/headers");
  (await cookies()).set("sculpt-theme", theme, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
  revalidatePath("/", "layout");
}

/** Switch to the other template: archive the current program, clone fresh. */
export async function switchProgram(templateName: string) {
  const { supabase, userId } = await requireUserId();
  if (!TEMPLATE_NAMES.includes(templateName as (typeof TEMPLATE_NAMES)[number])) {
    return { ok: false as const, error: "Unknown program." };
  }
  await supabase
    .from("programs")
    .update({ active: false })
    .eq("user_id", userId)
    .eq("active", true);
  const ok = await cloneTemplateProgram(supabase, userId, templateName);
  revalidatePath("/", "layout");
  return ok
    ? { ok: true as const }
    : { ok: false as const, error: "Template not found — run the latest SQL." };
}

/**
 * Restart the current program from scratch: archive the customized copy and
 * re-clone its own template fresh. Wipes every added/swapped/goal-focus
 * exercise and resets to the beginning (a fresh program has no logs, so the
 * cycle derives back to 1 / week 1). Logged history is kept on the archived
 * program, so PBs and trends survive.
 */
export async function restartProgram() {
  const { supabase, userId } = await requireUserId();
  const { data: current } = await supabase
    .from("programs")
    .select("name")
    .eq("user_id", userId)
    .eq("active", true)
    .maybeSingle();
  if (!current?.name) return { ok: false as const, error: "No active program." };

  await supabase
    .from("programs")
    .update({ active: false })
    .eq("user_id", userId)
    .eq("active", true);
  const ok = await cloneTemplateProgram(supabase, userId, current.name as string);
  revalidatePath("/", "layout");
  revalidatePath("/program");
  return ok
    ? { ok: true as const }
    : { ok: false as const, error: "Couldn't rebuild — run the latest SQL." };
}


/** One-time (editable) setup for the physique report: gender, height, goal. */
export async function saveFitnessProfile(formData: FormData) {
  const { supabase, userId } = await requireUserId();

  const gender = String(formData.get("gender") ?? "");
  if (!GENDERS.includes(gender as (typeof GENDERS)[number])) {
    return { ok: false as const, error: "Pick one." };
  }
  const height = parseFloat(String(formData.get("height_cm") ?? "").replace(",", "."));
  const heightCm =
    Number.isFinite(height) && height >= 120 && height <= 230 ? height : null;
  const goalNote = String(formData.get("goal_note") ?? "").trim().slice(0, 200) || null;

  await supabase
    .from("profiles")
    .update({ gender, height_cm: heightCm, goal_note: goalNote })
    .eq("id", userId);

  // Optional weight — logged to the diary so it feeds the report and trends.
  const weight = parseFloat(String(formData.get("weight") ?? "").replace(",", "."));
  if (Number.isFinite(weight) && weight > 0 && weight <= 400) {
    const date = new Date().toISOString().slice(0, 10);
    await supabase
      .from("body_weight")
      .upsert({ user_id: userId, date, weight_kg: weight }, { onConflict: "user_id,date" });
  }

  revalidatePath("/report");
  return { ok: true as const };
}

/** Analyze the latest progress photos into a new fitness report. */
export async function generateFitnessReport() {
  const { supabase, userId } = await requireUserId();
  const { analyzePhysique, isAiConfigured } = await import("@/lib/physique");

  if (!isAiConfigured()) {
    return { ok: false as const, error: "not_configured" };
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("gender, height_cm, goal_note")
    .eq("id", userId)
    .maybeSingle();
  if (!profile?.gender || profile.gender === null) {
    return { ok: false as const, error: "needs_setup" };
  }

  const [{ data: photos }, { data: bw }] = await Promise.all([
    supabase
      .from("progress_photos")
      .select("storage_path")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(3),
    supabase
      .from("body_weight")
      .select("weight_kg")
      .eq("user_id", userId)
      .order("date", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  const paths = ((photos ?? []) as { storage_path: string }[]).map((p) => p.storage_path);
  if (!paths.length) return { ok: false as const, error: "needs_photo" };

  // Download the private photos and inline them as base64. Claude vision only
  // reads jpeg/png/gif/webp — iPhone HEIC photos must be flagged, not sent
  // (they'd 400 and look like a generic failure).
  const SUPPORTED = ["image/jpeg", "image/png", "image/gif", "image/webp"];
  const extType: Record<string, string> = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    gif: "image/gif",
    webp: "image/webp",
  };
  const images: { base64: string; mediaType: string }[] = [];
  let skippedUnsupported = false;
  for (const path of paths) {
    const { data: blob } = await supabase.storage.from("progress-photos").download(path);
    if (!blob) continue;
    let mediaType = blob.type;
    if (!SUPPORTED.includes(mediaType)) {
      mediaType = extType[path.split(".").pop()?.toLowerCase() ?? ""] ?? "";
    }
    if (!SUPPORTED.includes(mediaType)) {
      skippedUnsupported = true;
      continue;
    }
    const buf = Buffer.from(await blob.arrayBuffer());
    images.push({ base64: buf.toString("base64"), mediaType });
  }
  if (!images.length) {
    return {
      ok: false as const,
      error: skippedUnsupported ? "unsupported_format" : "needs_photo",
    };
  }

  const outcome = await analyzePhysique({
    gender: profile.gender as "female" | "male" | "unspecified",
    heightCm: (profile.height_cm as number | null) ?? null,
    weightKg: (bw?.weight_kg as number | null) ?? null,
    goalNote: (profile.goal_note as string | null) ?? null,
    images,
  });

  if (!outcome.ok) {
    return {
      ok: false as const,
      error: outcome.reason === "not_configured" ? "not_configured" : "analysis_failed",
      // Surface the real reason so a failure can actually be diagnosed.
      detail: outcome.reason === "error" ? outcome.message?.slice(0, 200) : undefined,
    };
  }

  const r = outcome.result;
  const { data: report, error } = await supabase
    .from("fitness_reports")
    .insert({
      user_id: userId,
      assessable: r.assessable,
      overall_score: r.overall_score,
      level: r.level,
      next_level: r.next_level,
      metrics: r.metrics,
      strengths: r.strengths,
      focus_areas: r.focus_areas,
      focus_muscles: r.focus_muscles,
      plan: r.plan,
      summary: r.summary,
      next_level_advice: r.next_level_advice,
      body_weight_kg: (bw?.weight_kg as number | null) ?? null,
      photo_count: images.length,
      model: outcome.model,
    })
    .select("id")
    .single();

  if (error || !report) {
    return { ok: false as const, error: "save_failed" };
  }

  revalidatePath("/report");
  return { ok: true as const, reportId: report.id };
}

/**
 * Builds the report's plan into the active program as a separate, replaceable
 * "goal focus" block. Re-applying REPLACES the previous focus block rather
 * than stacking on top of it (otherwise repeated taps pile up accessories).
 * For each prioritized focus muscle (biggest problems first) it adds one
 * pump-tier accessory in that muscle group, spread across days so no day is
 * overloaded. Base exercises and compounds are never touched. Returns the
 * additions (with the coach's reason) and anything the rebuild replaced.
 */
export async function applyWeakPointFocus(reportId: string) {
  const { supabase, userId } = await requireUserId();

  const { data: report } = await supabase
    .from("fitness_reports")
    .select("plan, focus_muscles")
    .eq("id", reportId)
    .eq("user_id", userId)
    .maybeSingle();

  // Prefer the prioritized plan (muscle + reason); fall back to the bare
  // focus-muscle list on older reports.
  const planRows = (report?.plan ?? []) as { muscle: string; reason: string }[];
  const targets: { muscle: string; reason: string | null }[] = planRows.length
    ? planRows.map((p) => ({ muscle: p.muscle, reason: p.reason ?? null }))
    : ((report?.focus_muscles ?? []) as string[]).map((m) => ({
        muscle: m,
        reason: null,
      }));
  const ordered = targets.slice(0, 4);
  if (!ordered.length) return { ok: false as const, error: "No focus areas." };

  const { getActiveProgram } = await import("@/lib/data");
  const program = await getActiveProgram(supabase, userId);
  if (!program) return { ok: false as const, error: "No active program." };
  const dayIds = program.days.map((d) => d.id);

  // Clear the previous goal-focus block first, capturing it so we can show
  // what was replaced. Removing these rows never touches logged history
  // (set_logs reference the exercise, not the program slot).
  const { data: oldFocus } = await supabase
    .from("program_exercises")
    .select("exercise_id, exercise:exercises(name)")
    .in("program_day_id", dayIds)
    .eq("is_focus", true);
  type FocusRow = {
    exercise_id: string;
    exercise: { name: string } | { name: string }[] | null;
  };
  const oldFocusRows = (oldFocus ?? []) as FocusRow[];
  const replaced = oldFocusRows
    .map((r) => (Array.isArray(r.exercise) ? r.exercise[0]?.name : r.exercise?.name))
    .filter((n): n is string => !!n);
  if (oldFocus?.length) {
    await supabase
      .from("program_exercises")
      .delete()
      .in("program_day_id", dayIds)
      .eq("is_focus", true);
  }

  const { data: lib } = await supabase
    .from("exercises")
    .select("*")
    .eq("is_global", true);
  type Ex = { id: string; name: string; muscle_group: string; rep_profile: string };
  const library = (lib ?? []) as Ex[];

  // Base = everything except the focus block we just cleared, so a new pick
  // never duplicates a base exercise (but may re-use a just-removed one).
  const oldFocusExIds = new Set(oldFocusRows.map((r) => r.exercise_id));
  const baseDays = program.days.map((d) => ({
    id: d.id,
    name: d.name,
    base: d.exercises.filter((pe) => !oldFocusExIds.has(pe.exercise_id)),
  }));
  const inProgram = new Set(
    baseDays.flatMap((d) => d.base.map((pe) => pe.exercise_id))
  );
  const addedPerDay = new Map<string, number>();

  const changes: string[] = [];
  for (const { muscle, reason } of ordered) {
    if (changes.length >= 4) break;
    const pick = library.find(
      (e) =>
        e.muscle_group === muscle &&
        e.rep_profile === "pump" &&
        !inProgram.has(e.id)
    );
    if (!pick) continue;

    // Prefer the day that already trains this muscle (coherent), then the
    // one with the fewest new additions, then the lightest overall.
    const trains = (d: (typeof baseDays)[number]) =>
      d.base.filter((pe) => pe.exercise.muscle_group === muscle).length;
    const day = [...baseDays].sort((a, b) => {
      if (trains(b) !== trains(a)) return trains(b) - trains(a);
      const na = addedPerDay.get(a.id) ?? 0;
      const nb = addedPerDay.get(b.id) ?? 0;
      if (na !== nb) return na - nb;
      return a.base.length - b.base.length;
    })[0];
    if (!day) continue;

    const nextSort =
      Math.max(0, ...day.base.map((x) => x.sort)) +
      1 +
      (addedPerDay.get(day.id) ?? 0);
    const { error } = await supabase.from("program_exercises").insert({
      program_day_id: day.id,
      exercise_id: pick.id,
      sort: nextSort,
      sets: 3,
      is_focus: true,
    });
    if (error) continue;
    inProgram.add(pick.id);
    addedPerDay.set(day.id, (addedPerDay.get(day.id) ?? 0) + 1);
    changes.push(
      reason
        ? `${pick.name} → ${day.name} · ${reason}`
        : `Added ${pick.name} to ${day.name}`
    );
  }

  if (!changes.length) {
    return { ok: false as const, error: "Your program already covers these." };
  }
  revalidatePath("/program");
  revalidatePath("/report");
  return { ok: true as const, changes, replaced };
}

// -------------------------------------------------------------------- auth

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
