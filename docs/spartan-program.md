# Sculpt — Spartan: default men's template ("Strong & Built")

Designed and self-audited by the fitness-coach agent. Goal: strong,
athletic, V-taper — chest/back/shoulders/arms emphasis, one honest leg
day, core woven in. Runs unchanged on the existing engine: 3-week
light/medium/hard wave, 3 sets, 5 days, 3/5 completes a week.

Day order matters for the 3/5 skip bias: Push / Pull / Legs are listed
first, so a 3-session week is a complete PPL mini-week. Days 4–5 are the
specialization volume that earns the star.

---

## 1. New exercises needed (13)

All `is_global = true`, `unit = 'kg'`.

| # | Name | muscle_group | movement_pattern | equipment | rep_profile | Cue |
|---|------|--------------|------------------|-----------|-------------|-----|
| 1 | Barbell Bench Press | chest | push | barbell | strength | Shoulder blades pinned, feet planted. Lower to the chest with control, press back over the shoulders. |
| 2 | Overhead Press | shoulders | push | barbell | strength | Glutes tight, ribs down. Press to lockout and bring your head through at the top. |
| 3 | Weighted Dip | chest | push | dip station | strength | Slight forward lean, elbows tracking back, deep stretch. Earn strict bodyweight reps before adding plates. |
| 4 | Weighted Pull-Up | back | pull | pull-up bar | strength | Full hang, then drive the elbows down to your ribs. Chin over the bar, no kicking. |
| 5 | Barbell Row | back | pull | barbell | strength | Hinge to forty-five degrees and brace like a deadlift. Pull to the lower ribs — the lats do the work. |
| 6 | Close-Grip Bench Press | arms | push | barbell | strength | Hands just inside shoulder width, elbows tucked. Touch low on the chest, press with the triceps. |
| 7 | Face Pull | shoulders | pull | cable | pump | Rope to the bridge of the nose, elbows high and wide. Finish like a double-biceps pose, pause a beat. |
| 8 | Dumbbell Rear Delt Fly | shoulders | pull | dumbbells | pump | Hinge over, soft elbows. Sweep wide and lead with the pinkies — no momentum. |
| 9 | Reverse Pec Deck | shoulders | pull | machine | pump | Arms long, sweep back until the hands pass the shoulders. Pause where it burns. |
| 10 | Band Pull-Apart | shoulders | pull | band | pump | Arms straight, pull the band to your chest. Squeeze the blades together, control the return. |
| 11 | Dumbbell Front Raise | shoulders | push | dumbbells | pump | Raise to eye level, no lean-back. Lighter than pride suggests. |
| 12 | Cable Fly | chest | push | cable | pump | Slight elbow bend, like hugging a barrel. Deep stretch, then squeeze the hands together. |
| 13 | Machine Chest Fly | chest | push | machine | pump | Open wide into the stretch — that's where chests grow. Squeeze the handles together and pause. |

Notes:
- 1–8 are required by program slots; 9–11 give the rear-delt and
  lateral-raise slots real swap pools; 12–13 are library depth only.
- Deliberately not added: chin-up (pull-strength pool already 8 deep),
  shrugs (rows/deadlifts/face pulls cover traps), leg extension (no
  quad-isolation group exists), Nordic curl (fights the rep engine).

---

## 2. The five days

### Day 1 — Push
1. Barbell Bench Press (strength)
2. Overhead Press (strength)
3. Weighted Dip (strength)
4. Lateral Raises (pump)
5. Triceps Rope Pushdown (pump)
6. Overhead Cable Triceps Extension (pump)

**Rationale:** "The two presses that build a chest and a pair of
shoulders come first, while you're strongest — flat for mass, overhead
for the frame that carries it. Dips load the chest at a deep stretch,
the exact range presses miss. Side delts and triceps finish high-rep on
purpose: that's the range small muscles actually respond to, and it's
where the width comes from."

### Day 2 — Pull
1. Weighted Pull-Up (strength)
2. Barbell Row (strength)
3. Seated Cable Row (strength)
4. Face Pull (pump)
5. EZ-Bar Curls (pump)
6. Hammer Curls (pump)

**Rationale:** "The V-taper is built here. Pull-ups widen the lats from
above, rows thicken the mid-back from straight on — vertical and
horizontal pulling are different jobs, so both get a heavy slot. Face
pulls keep the rear delts and rotator cuff honest against all that
pressing, and biceps finish the day already warm from every row before
them."

### Day 3 — Legs
1. Back Squat (strength)
2. Romanian Deadlift (strength)
3. Bulgarian Split Squat (strength, lunge wave 6–8 hard)
4. Lying Leg Curl (pump)
5. Calf Raises (pump)
6. Hanging Knee Raise (pump)

**Rationale:** "One leg day, done properly. The squat is the biggest
lift of the week, so it goes first; the RDL loads the hamstrings at long
length where growth is best stimulated; split squats add the single-leg
strength that makes you athletic, not just big. Legs hold the frame up —
a taper on toothpicks isn't one. Core closes the day hanging from a bar."

### Day 4 — Shoulders & Arms
1. Dumbbell Shoulder Press (strength)
2. Close-Grip Bench Press (strength)
3. Cable Lateral Raises (pump)
4. Dumbbell Rear Delt Fly (pump)
5. Cable Curls (pump)
6. Skullcrushers (pump)

**Rationale:** "Width and arms get their own day. Shoulder width is
mostly side delts, and side delts are mostly volume — cables keep
tension on every centimetre of the raise. The close-grip bench gives
triceps a heavy compound instead of only pushdowns, and rear delts get
direct work so the shoulders look as good from behind as from the
front. Arms finish the day; they've been working since rep one."

### Day 5 — Chest, Back & Core
1. Incline Dumbbell Press (strength)
2. Lat Pulldown (strength)
3. Chest-Supported Row (strength)
4. Straight-Arm Pulldown (pump)
5. Ab Wheel Rollout (pump)
6. Hollow Hold (timed)

**Rationale:** "The second hit for the muscles that make the silhouette.
Incline pressing fills in the upper chest; the pulldown and
chest-supported row add lat width with the lower back fully unloaded
after the week's barbell work. Straight-arm pulldowns isolate the lats
one last time, then the core pair trains the trunk's two real jobs —
moving under load and refusing to move at all."

---

## 3. Self-audit (coach)

- **Push/pull balance:** 11 push (33 sets) vs 11 pull (33 sets) — dead
  even; rear delts and rows protect shoulders from five pressing slots.
- **Pattern coverage:** push, pull, squat, hinge, lunge, core, accessory
  present. Thrust and abduction intentionally absent (glute-
  specialization patterns; library still has them for self-editing).
- **Recovery spacing:** no muscle hit heavily back-to-back. One mild
  overlap (barbell row erectors → squat/RDL next day) at recreational
  loads; chest-supported row is the sanctioned swap if a lower back
  complains — which is why conventional deadlift is NOT on Pull day.
- **Hard-week sanity:** every strength slot safe and productive at 4–6;
  BSS inherits the lunge exception (6–8); pump slots bottom at 10–12.
  Weighted Dip/Pull-Up start bodyweight in light week; log added kg.
- **3/5 skip bias:** first three days form a complete PPL mini-week;
  least-recently-trained rotation brings days 4–5 in over time.
- **Swap pools:** every slot has ≥3 legal swaps. Flags: Close-Grip Bench
  is the only arms/push/strength exercise (swaps are pump-role);
  Lying Leg Curl has 2 same-role siblings (pre-existing, shared with
  the women's program).
- **Weekly volume:** chest ~12 hard sets, back ~15, side delts 6 direct,
  rear delts 6, biceps 9, triceps 9 + 6 compound, quads ~9, hams ~6,
  core 9, calves 3 — emphasized muscles in/near the 10–20 range.
- **Equipment:** barbell + bench, rack, dip station, pull-up bar, two
  cable stacks, dumbbells; every slot machine-swappable.

---

## 4. Share prompts (SHARE_PROMPTS additions, keyed by day name)

```
"Push": "Pressing done. The pump fades by tonight — the log doesn't. One photo, no caption needed.",
"Pull": "You can't see your own back. That's what the camera and the friends are for.",
"Legs": "Leg day, finished, in full. Nobody trains legs for the feed — which is exactly why it belongs there.",
"Shoulders & Arms": "Sleeves are tighter than they were an hour ago. Document it and move on.",
"Chest, Back & Core": "Fifth day down. Quiet week of work — let the record show it.",
```

Spartan fallback: `"Done. Stand there a second. Then send the proof."`

## 5. Quote additions (spartan-discipline, calm)

```
('Discipline outlasts motivation. Plan accordingly.', null),
('The bar is honest. Match it.', null),
('No one is coming to lift it for you.', null),
('Endure quietly. Add weight slowly.', null),
('Comfort is a debt the body collects later.', null),
('Show up like it''s a duty. Leave like it''s a privilege.', null),
('A disciplined hour beats an inspired month.', null),
('Heavy is a teacher. Listen.', null),
('It is a disgrace to grow old without seeing the strength your body is capable of.', 'Socrates'),
('Waste no more time arguing what a good man should be. Be one.', 'Marcus Aurelius'),
('Spartans do not ask how many the enemy are, only where they are.', 'Agis II'),
```

## Implementation notes

- Program seed: clone the template block in `supabase/setup_all.sql`
  with `name = 'Strong & Built'`, day names Push / Pull / Legs /
  Shoulders & Arms / Chest, Back & Core, and the 30 (day, sort, name)
  rows above.
- New exercises slot into the existing insert format; the
  `on conflict (name) where is_global do nothing` guard keeps it
  idempotent. Set `rep_profile` inline.
- Copy additions go in `src/lib/programCopy.ts` (keys are day names, so
  they just work). No engine changes needed.
- New exercises will need instruction videos (same research process as
  0003/0008).
