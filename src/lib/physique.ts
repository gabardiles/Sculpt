import Anthropic from "@anthropic-ai/sdk";

/**
 * Physique-report analysis. A supportive strength coach scores a member's
 * training development from progress photos on a 0–10 scale across fixed
 * axes, names strengths and weak points, and maps the weak points to the
 * app's muscle-group vocabulary so the program can be biased toward them.
 *
 * The model is asked to assess *training development*, never attractiveness
 * or worth, and to keep body-fat talk as a gentle visual range — this is
 * fitness coaching, not medical advice. State is small and one-shot.
 */

const MODEL = "claude-opus-4-8";

/** Fixed scored axes — the UI renders a stable label per key. */
export const METRIC_KEYS = [
  "conditioning",
  "core",
  "upper",
  "lower",
  "arms",
  "proportion",
] as const;

/** App muscle groups the weak-point plan can target. */
const FOCUS_MUSCLES = [
  "glutes",
  "hamstrings",
  "quads",
  "back",
  "chest",
  "shoulders",
  "arms",
  "core",
  "calves",
] as const;

export interface PhysiqueInput {
  gender: "female" | "male" | "unspecified";
  heightCm: number | null;
  weightKg: number | null;
  goalNote: string | null;
  images: { base64: string; mediaType: string }[];
}

export interface PhysiqueResult {
  assessable: boolean;
  overall_score: number;
  level: string;
  next_level: string;
  metrics: { key: string; label: string; score: number; comment: string }[];
  strengths: string[];
  focus_areas: string[];
  focus_muscles: string[];
  summary: string;
  next_level_advice: string;
}

export type AnalyzeOutcome =
  | { ok: true; result: PhysiqueResult; model: string }
  | { ok: false; reason: "not_configured" | "error"; message?: string };

export function isAiConfigured(): boolean {
  return !!process.env.ANTHROPIC_API_KEY;
}

export const RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    assessable: {
      type: "boolean",
      description:
        "True only if the photos clearly show enough of the body to judge training development. False for face-only selfies, heavy clothing, or unusable framing/lighting.",
    },
    overall_score: { type: "number", description: "0–10, one decimal." },
    level: {
      type: "string",
      description:
        "Current development tier, one of: Starting out, Developing, Fit, Athletic, Sculpted, Elite.",
    },
    next_level: { type: "string", description: "The next tier up." },
    metrics: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          key: { type: "string", enum: [...METRIC_KEYS] },
          label: { type: "string" },
          score: { type: "number", description: "0–10, one decimal." },
          comment: {
            type: "string",
            description: "One encouraging, specific sentence.",
          },
        },
        required: ["key", "label", "score", "comment"],
      },
    },
    strengths: {
      type: "array",
      items: { type: "string" },
      description: "2–4 genuine good points, plain language.",
    },
    focus_areas: {
      type: "array",
      items: { type: "string" },
      description: "2–3 weak points to improve, framed as opportunities.",
    },
    focus_muscles: {
      type: "array",
      items: { type: "string", enum: [...FOCUS_MUSCLES] },
      description: "1–3 app muscle groups to bias training toward.",
    },
    summary: {
      type: "string",
      description: "2–3 warm sentences summarizing where they are.",
    },
    next_level_advice: {
      type: "string",
      description:
        "2–3 sentences on the concrete changes that reach the next level.",
    },
  },
  required: [
    "assessable",
    "overall_score",
    "level",
    "next_level",
    "metrics",
    "strengths",
    "focus_areas",
    "focus_muscles",
    "summary",
    "next_level_advice",
  ],
} as const;

function aestheticTarget(gender: PhysiqueInput["gender"]): string {
  if (gender === "male") {
    return "Athletic and strong: a clear V-taper (broad shoulders, fuller chest and back, tighter waist), visible core, developed arms, and athletic legs. Lean and muscular, not bulky.";
  }
  if (gender === "female") {
    return "Lean, toned and sculpted — the 'Alo yoga' aesthetic: defined but not bulky shoulders and back, a tight midsection, firm rounded glutes, lean legs, and graceful overall proportion at a low-to-moderate body fat.";
  }
  return "A balanced athletic, lean and toned physique with even development head to toe.";
}

function clamp10(n: unknown): number {
  const v = typeof n === "number" && Number.isFinite(n) ? n : 0;
  return Math.max(0, Math.min(10, Math.round(v * 10) / 10));
}

/**
 * Normalize and harden the model's JSON into a stored report. Structured
 * outputs make the shape reliable, but this still clamps scores, drops
 * unknown metric/muscle keys, and bounds string lengths so a surprising
 * response can never write junk or oversized rows.
 */
export function normalizePhysiqueResult(raw: Partial<PhysiqueResult>): PhysiqueResult {
  return {
    assessable: !!raw.assessable,
    overall_score: clamp10(raw.overall_score),
    level: String(raw.level ?? "").slice(0, 40),
    next_level: String(raw.next_level ?? "").slice(0, 40),
    metrics: (Array.isArray(raw.metrics) ? raw.metrics : [])
      .filter((m) => METRIC_KEYS.includes(m?.key as (typeof METRIC_KEYS)[number]))
      .map((m) => ({
        key: m.key,
        label: String(m.label ?? "").slice(0, 60),
        score: clamp10(m.score),
        comment: String(m.comment ?? "").slice(0, 300),
      })),
    strengths: (Array.isArray(raw.strengths) ? raw.strengths : [])
      .slice(0, 5)
      .map((s) => String(s).slice(0, 200)),
    focus_areas: (Array.isArray(raw.focus_areas) ? raw.focus_areas : [])
      .slice(0, 5)
      .map((s) => String(s).slice(0, 200)),
    focus_muscles: (Array.isArray(raw.focus_muscles) ? raw.focus_muscles : [])
      .filter((m) => FOCUS_MUSCLES.includes(m as (typeof FOCUS_MUSCLES)[number]))
      .slice(0, 3),
    summary: String(raw.summary ?? "").slice(0, 600),
    next_level_advice: String(raw.next_level_advice ?? "").slice(0, 600),
  };
}

export async function analyzePhysique(
  input: PhysiqueInput
): Promise<AnalyzeOutcome> {
  if (!isAiConfigured()) return { ok: false, reason: "not_configured" };
  if (!input.images.length) {
    return { ok: false, reason: "error", message: "No photos to analyze." };
  }

  const stats = [
    input.heightCm ? `${input.heightCm} cm tall` : null,
    input.weightKg ? `${input.weightKg} kg` : null,
  ]
    .filter(Boolean)
    .join(", ");

  const system = `You are an experienced, supportive strength and physique coach giving a member a progress check from their training photos.

Assess TRAINING DEVELOPMENT only — muscular development, conditioning, symmetry and proportion. Never comment on attractiveness, worth, or anything outside training. Keep any body-fat read as a gentle visual range, never a precise medical figure. This is fitness coaching, not medical advice. Be honest and specific so the scores are useful, but always kind and motivating — this person is showing up.

Their aesthetic goal: ${aestheticTarget(input.gender)}

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

  const goalLine = input.goalNote
    ? `Their stated dream focus: "${input.goalNote}". Weigh this in the focus areas and advice.`
    : "They have no specific stated goal beyond the aesthetic above.";

  const userText = `Here ${input.images.length === 1 ? "is my latest progress photo" : `are my ${input.images.length} latest progress photos`}.${stats ? ` I'm ${stats}.` : ""} ${goalLine}\n\nGive me my fitness report.`;

  const client = new Anthropic();
  try {
    const message = await client.messages.create({
      model: MODEL,
      max_tokens: 2048,
      system,
      output_config: {
        format: { type: "json_schema", schema: RESPONSE_SCHEMA as Record<string, unknown> },
      },
      messages: [
        {
          role: "user",
          content: [
            ...input.images.map((img) => ({
              type: "image" as const,
              source: {
                type: "base64" as const,
                media_type: img.mediaType as "image/jpeg" | "image/png" | "image/webp",
                data: img.base64,
              },
            })),
            { type: "text" as const, text: userText },
          ],
        },
      ],
    });

    const text = message.content
      .filter((b): b is Anthropic.TextBlock => b.type === "text")
      .map((b) => b.text)
      .join("");
    const result = normalizePhysiqueResult(
      JSON.parse(text) as Partial<PhysiqueResult>
    );
    return { ok: true, result, model: MODEL };
  } catch (e) {
    return {
      ok: false,
      reason: "error",
      message: e instanceof Error ? e.message : "Analysis failed.",
    };
  }
}
