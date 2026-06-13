# AI Fitness Report

A coach's read of the member's training photos: a 0–10 score per body area,
an overall score and level, genuine strengths, weak points, what reaches the
next level, and a one-tap action that biases the program toward the weak
points. Lives in its own **Report** tab.

## How it works

1. **One-time setup** (editable anytime): goal aesthetic (lean & toned /
   athletic & strong / balanced), height, weight, and an optional "dream
   focus" (e.g. *a visible six-pack*). Stored on `profiles`
   (`gender`, `height_cm`, `goal_note`); weight is shared with the weight
   diary (`body_weight`).
2. **Analyze**: the server action `generateFitnessReport` downloads the
   member's most recent progress photos (up to 3, from the private
   `progress-photos` bucket), inlines them as base64, and calls Claude
   (`claude-opus-4-8`) with a structured-output JSON schema
   (`src/lib/physique.ts`). The result is stored in `fitness_reports`.
3. **The report** renders the overall score, six scored axes as 0–10 dotted
   lines (`DotScale`), strengths, weak points, next-level advice, and the
   weak-point CTA. New reports stack into a history list.
4. **Focus my weak points**: `applyWeakPointFocus` adds pump-tier accessory
   exercises for the report's `focus_muscles` into the active program, using
   the same same-muscle guardrail as the swap engine — compounds untouched,
   up to three additions, each to the day that already trains that muscle
   most.

## Scoring

Six fixed axes, each 0–10 (`src/lib/physique.ts` → `METRIC_KEYS`):
leanness/conditioning, core, upper body, lower body, arms, and
posture/proportion. Anchors: 0–2 starting, 3–4 developing, 5–6 fit, 7–8
athletic/sculpted, 9–10 elite. The aesthetic target is gendered (V-taper and
strength for men; lean, toned "Alo" sculpting for women), so the same photo
scores against the member's own goal.

The system prompt constrains the model to assess **training development**
only — never attractiveness or worth — keeps body-fat talk to a gentle
visual range, and frames everything as supportive coaching, not medical
advice. Unreadable photos (face-only, heavy clothing) come back with
`assessable: false` and a prompt for a clearer photo instead of fake scores.

## Configuration

Set `ANTHROPIC_API_KEY` (server-only) in the environment. Without it,
`isAiConfigured()` is false and the Report tab shows a friendly
"not switched on yet" notice — the rest of the UI (setup, history) still
works. Each analysis costs a few cents of vision tokens.

Run `supabase/setup_all.sql` to add the `fitness_reports` table, the profile
columns, and RLS.
