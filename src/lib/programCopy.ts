/**
 * The "why" behind the program — written by the training intelligence that
 * designed it, audited against current hypertrophy evidence. Keyed by day
 * name so it follows template-derived programs.
 */

export const DAY_RATIONALE: Record<string, string> = {
  "Glutes & Hamstrings":
    "Hinge day. The RDL loads your glutes and hamstrings at long muscle " +
    "length — where growth is best stimulated — then hip thrusts hit the " +
    "squeeze at lockout, the exact opposite point. Together they cover the " +
    "full strength curve. The leg curl at the end adds direct hamstring " +
    "work the hinges can't fully provide.",
  "Upper Body Lean":
    "Balanced pull and press. The pulldown and bench press build the back " +
    "and chest that shape posture; strict shoulder presses and lateral " +
    "raises round the shoulders without bulk — raises stay light and high-" +
    "rep on purpose, that's how side delts respond. Arms finish the day " +
    "when they're warm.",
  "Glutes & Quads":
    "Squat day. Back squat first while you're fresh — it's the biggest " +
    "lift of the week. Lunges and the high-and-wide leg press bias glutes " +
    "through deep ranges, the thrust machine adds lockout squeeze, and " +
    "abduction targets the upper glute that gives the rounded side profile.",
  "Core & Back":
    "Strength that holds everything together. Rows and pulldowns build the " +
    "back; the glute-biased back extension keeps hip extension volume up " +
    "mid-week without heavy loading. The core trio — crunch, anti-rotation " +
    "press, plank — trains the trunk in all three jobs it actually has: " +
    "flexing, resisting twist, and holding still.",
  "Booty Volume":
    "Pump day, by design lighter on the joints. Two compounds first while " +
    "fresh, then kickbacks, pumps and banded walks chase blood and burn " +
    "rather than load — metabolic stress is a real growth signal, and it " +
    "leaves you recovered for the next hinge day.",
};

export const WHY_SWAPS =
  "Swaps only offer exercises with the same movement pattern and the same " +
  "primary muscle — a back squat can become a hack squat or leg press, " +
  "never a bicep curl. Same-role options (heavy compound for heavy " +
  "compound, pump for pump) come first, so the training effect survives " +
  "the swap. Machines and free weights are interchangeable here: the " +
  "muscle doesn't know what's loading it, so pick what your gym and your " +
  "body like.";

export const HOW_IT_WORKS = [
  {
    title: "The cycle",
    body:
      "Sculpt runs in 3-week cycles. Week 1 is light (10–12 reps), week 2 " +
      "medium (6–8), week 3 hard (4–6) — same exercises, heavier each " +
      "week. Pump exercises wave too, just in higher ranges where they " +
      "actually work, and timed holds wave in seconds.",
  },
  {
    title: "A week",
    body:
      "Five sessions are on the menu, in any order you like. Three of " +
      "five completes the week — that's a real, sustainable training week, " +
      "not a failure. All five earns the star. From three sessions you can " +
      "close the week and move on.",
  },
  {
    title: "After week 3",
    body:
      "The cycle rolls over automatically: back to a light week, one " +
      "cycle number higher. Your light-week weights should now be close to " +
      "what medium week was last cycle — that's progressive overload " +
      "doing its quiet work. The Program tab keeps the history of every " +
      "cycle, including how each one felt.",
  },
  {
    title: "Listening to the body",
    body:
      "You rate every session 1–5. If a hard week consistently feels like " +
      "a 2, the app suggests repeating a medium week — strength is built " +
      "by recovering from training, not by surviving it.",
  },
  {
    title: "Why these exercises",
    body:
      "The split is glute-biased on purpose — three of five days train " +
      "glutes, through all three of their jobs: hinging, thrusting and " +
      "abduction. Pressing and pulling are balanced for posture, and the " +
      "core work covers bracing, anti-rotation and holds. Each day's " +
      "screen explains its own logic.",
  },
];
