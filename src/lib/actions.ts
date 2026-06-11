"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient, createAdminClient } from "@/lib/supabase/server";
import type { Phase } from "@/lib/types";

async function requireUserId() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  return { supabase, userId: user.id };
}

// ------------------------------------------------------------- onboarding

export async function completeOnboarding(formData: FormData) {
  const { supabase, userId } = await requireUserId();
  const name = String(formData.get("name") ?? "").trim();
  if (!name) return;

  await supabase.from("profiles").update({ name }).eq("id", userId);

  // Clone the global template program if she doesn't have one yet.
  const { data: existing } = await supabase
    .from("programs")
    .select("id")
    .eq("user_id", userId)
    .eq("active", true)
    .maybeSingle();

  if (!existing) {
    const { data: template } = await supabase
      .from("programs")
      .select("*, program_days(*, program_exercises(*))")
      .is("user_id", null)
      .eq("active", true)
      .limit(1)
      .maybeSingle();

    if (template) {
      const { data: program } = await supabase
        .from("programs")
        .insert({
          user_id: userId,
          name: template.name,
          weeks: template.weeks,
          days_per_week: template.days_per_week,
          active: true,
        })
        .select("id")
        .single();

      if (program) {
        type TemplateDay = {
          day_index: number;
          name: string;
          program_exercises: { exercise_id: string; sort: number; sets: number }[];
        };
        for (const day of (template.program_days ?? []) as TemplateDay[]) {
          const { data: newDay } = await supabase
            .from("program_days")
            .insert({
              program_id: program.id,
              day_index: day.day_index,
              name: day.name,
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
              }))
            );
          }
        }
      }
    }
  }

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
  phase: Phase;
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

// ---------------------------------------------------------------- program

/** Close the current week from 3/5 sessions — checkbox week, on to the next. */
export async function closeWeek(cycle: number, phase: Phase) {
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
  if (!["body_weight", "exercise_pr", "consistency"].includes(type)) return;
  const target = parseFloat(String(formData.get("target") ?? "").replace(",", "."));
  if (!Number.isFinite(target) || target <= 0) return;
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

  // Create the account directly (no invite link — login is by emailed
  // 6-digit code, so nothing depends on redirect-URL configuration).
  const admin = createAdminClient();
  const { error } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    user_metadata: { invited_by: userId },
  });
  if (error) {
    return {
      ok: false as const,
      error: error.message.toLowerCase().includes("already")
        ? "She's already invited — she can just sign in."
        : error.message,
    };
  }
  return { ok: true as const };
}

// -------------------------------------------------------------------- auth

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
