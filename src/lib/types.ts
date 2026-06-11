export type Phase = "light" | "medium" | "hard";

export type MovementPattern =
  | "hinge"
  | "squat"
  | "lunge"
  | "thrust"
  | "abduction"
  | "push"
  | "pull"
  | "core"
  | "accessory";

export type GoalType = "body_weight" | "exercise_pr" | "consistency";

export interface Profile {
  id: string;
  name: string | null;
  is_admin: boolean;
  invited_by: string | null;
  friend_code: string;
  created_at: string;
}

export type FeedPostType = "workout" | "pb" | "photo" | "message";

export interface FeedPost {
  id: string;
  user_id: string;
  type: FeedPostType;
  body: string | null;
  storage_path: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface Program {
  id: string;
  user_id: string | null; // null = global template
  name: string;
  weeks: number;
  days_per_week: number;
  active: boolean;
  cycle_floor: number;
}

export interface ProgramDay {
  id: string;
  program_id: string;
  day_index: number;
  name: string;
}

export interface Exercise {
  id: string;
  name: string;
  short_label: string | null;
  muscle_group: string;
  movement_pattern: MovementPattern;
  equipment: string | null;
  instruction_url: string | null;
  cue: string | null;
  image_url: string | null;
  unit: "kg" | "s";
  is_global: boolean;
}

export interface ProgramExercise {
  id: string;
  program_day_id: string;
  exercise_id: string;
  sort: number;
  sets: number;
  exercise?: Exercise;
}

export interface WorkoutLog {
  id: string;
  user_id: string;
  program_day_id: string;
  week_phase: Phase;
  cycle_number: number;
  completed_at: string;
  feel_rating: number | null;
}

export interface SetLog {
  id: string;
  workout_log_id: string;
  exercise_id: string;
  weight_kg: number | null;
  reps: number | null;
}

export interface BodyWeight {
  id: string;
  user_id: string;
  date: string;
  weight_kg: number;
}

export interface ProgressPhoto {
  id: string;
  user_id: string;
  cycle_number: number;
  week_label: string;
  storage_path: string;
  created_at: string;
}

export interface Goal {
  id: string;
  user_id: string;
  type: GoalType;
  target_value: number;
  baseline_value: number | null;
  exercise_id: string | null;
  deadline: string | null;
  achieved: boolean;
  created_at: string;
  exercise?: Exercise;
}

export interface Quote {
  id: string;
  text: string;
  author: string | null;
}
