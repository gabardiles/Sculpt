/**
 * The "why" behind the program — written by the training intelligence that
 * designed it, audited against current hypertrophy evidence. Keyed by day
 * name so it follows template-derived programs.
 */

/** Post-workout share nudges — gym selfies are the love language. */
export const SHARE_PROMPTS: Record<string, string> = {
  "Glutes & Hamstrings":
    "Glutes are awake. Snap one for the feed — your friends want proof.",
  "Upper Body Lean":
    "That upper-body pump won't last forever. The mirror is right there.",
  "Glutes & Quads":
    "Leg day survived. Proof or it didn't happen.",
  "Core & Back":
    "Back day done — flex it. Snap the back, share the win.",
  "Booty Volume":
    "Pump day complete. This is exactly what gym selfies were invented for.",
};

export const SHARE_PROMPT_FALLBACK =
  "Done. Show your friends what showing up looks like.";

// Spartan ("Strong & Built") share prompts — masculine-calm, no bro energy.
Object.assign(SHARE_PROMPTS, {
  Push: "Pressing done. The pump fades by tonight — the log doesn't. One photo, no caption needed.",
  Pull: "You can't see your own back. That's what the camera and the friends are for.",
  Legs: "Leg day, finished, in full. Nobody trains legs for the feed — which is exactly why it belongs there.",
  "Shoulders & Arms":
    "Sleeves are tighter than they were an hour ago. Document it and move on.",
  "Chest, Back & Core":
    "Fifth day down. Quiet week of work — let the record show it.",
});

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

// Spartan ("Strong & Built") day rationales.
Object.assign(DAY_RATIONALE, {
  Push:
    "The two presses that build a chest and a pair of shoulders come first, " +
    "while you're strongest — flat for mass, overhead for the frame that " +
    "carries it. Dips load the chest at a deep stretch, the exact range " +
    "presses miss. Side delts and triceps finish high-rep on purpose: " +
    "that's the range small muscles respond to, and where the width comes from.",
  Pull:
    "The V-taper is built here. Pull-ups widen the lats from above, rows " +
    "thicken the mid-back from straight on — vertical and horizontal pulling " +
    "are different jobs, so both get a heavy slot. Face pulls keep the rear " +
    "delts honest against all that pressing, and biceps finish the day " +
    "already warm from every row before them.",
  Legs:
    "One leg day, done properly. The squat is the biggest lift of the week, " +
    "so it goes first; the RDL loads the hamstrings at long length where " +
    "growth is best stimulated; split squats add the single-leg strength " +
    "that makes you athletic, not just big. Core closes the day hanging " +
    "from a bar.",
  "Shoulders & Arms":
    "Width and arms get their own day. Shoulder width is mostly side delts, " +
    "and side delts are mostly volume — cables keep tension on every " +
    "centimetre of the raise. The close-grip bench gives triceps a heavy " +
    "compound, and rear delts get direct work so the shoulders look as good " +
    "from behind as from the front.",
  "Chest, Back & Core":
    "The second hit for the muscles that make the silhouette. Incline " +
    "pressing fills in the upper chest; the pulldown and chest-supported row " +
    "add lat width with the lower back fully unloaded. Then the core pair " +
    "trains the trunk's two real jobs — moving under load and refusing to " +
    "move at all.",
});

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
      "doing its quiet work. Between cycles, Sculpt reviews how the cycle " +
      "felt and may suggest refreshing an accessory or two whose weights " +
      "have gone flat. The big lifts always stay — you can't progress " +
      "what you keep changing.",
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
