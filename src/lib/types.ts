export type Phase = "light" | "medium" | "hard";

/**
 * Week intensity for fixed-schedule programs — the phase vocabulary plus
 * 'test' (benchmark weeks). 'hard' renders as HEAVY in hybrid programs.
 */
export type WeekIntensity = Phase | "test";

/** Session flavour for fixed-schedule programs. */
export type SessionType = "strength" | "crossfit" | "conditioning";

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

export type GoalType =
  | "body_weight"
  | "exercise_pr"
  | "consistency"
  | "fitness_score";

/** Training role — drives rep targets per phase and swap tiering. */
export type RepProfile = "strength" | "pump" | "timed";

export interface Profile {
  id: string;
  name: string | null;
  is_admin: boolean;
  invited_by: string | null;
  friend_code: string;
  theme: "sculpt" | "spartan";
  /** For the physique report's gendered aesthetic target. */
  gender: "female" | "male" | "unspecified" | null;
  age: number | null;
  height_cm: number | null;
  /** Free-text "dream" focus, e.g. "visible six-pack". */
  goal_note: string | null;
  created_at: string;
}

/** One scored axis of a physique report (0–10). */
export interface FitnessMetric {
  key: string;
  label: string;
  score: number;
  comment: string;
}

export interface FitnessReport {
  id: string;
  user_id: string;
  assessable: boolean;
  overall_score: number;
  level: string | null;
  next_level: string | null;
  metrics: FitnessMetric[];
  strengths: string[];
  focus_areas: string[];
  /** App muscle groups to bias the weak-point plan toward. */
  focus_muscles: string[];
  summary: string | null;
  next_level_advice: string | null;
  body_weight_kg: number | null;
  photo_count: number;
  model: string | null;
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
  /** 'cycle' = repeating 3-week wave; 'fixed' = distinct prescribed weeks. */
  schedule_mode: "cycle" | "fixed";
}

/** One prescribed week of a fixed-schedule program. */
export interface ProgramWeek {
  id: string;
  program_id: string;
  week_index: number;
  intensity: WeekIntensity;
  label: string | null;
  note: string | null;
}

export interface ProgramDay {
  id: string;
  program_id: string;
  day_index: number;
  name: string;
  /** Fixed-schedule programs only — null on cycle programs. */
  week_index: number | null;
  /** Calendar slot, 1 = Monday … 7 = Sunday. */
  weekday: number | null;
  session_type: SessionType;
  /** Written session body: warmup, WOD, heart-rate zones. */
  content: string | null;
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
  rep_profile: RepProfile;
  is_global: boolean;
}

export interface ProgramExercise {
  id: string;
  program_day_id: string;
  exercise_id: string;
  sort: number;
  sets: number;
  /** Coach prescription shown verbatim — replaces the derived rep target. */
  scheme: string | null;
  exercise?: Exercise;
}

export interface WorkoutLog {
  id: string;
  user_id: string;
  program_day_id: string;
  /** Fixed-schedule programs store week intensity here (incl. 'test'). */
  week_phase: WeekIntensity;
  /** Fixed-schedule programs store week_index here. */
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
