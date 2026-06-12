-- ============================================================================
-- Hybrid Athlete — 20-week fixed-schedule template
--
-- The coach's system, encoded: LIGHT / MEDIUM / HEAVY week undulation,
-- three session types (strength @ % of 1RM, CrossFit, heart-rate-zone
-- conditioning), a taper + TEST week mid-program (wk 12) and at the end
-- (wk 20), and four block weeks (15–18) that concentrate one modality.
--
-- Run AFTER setup_all.sql (it needs schedule_mode / program_weeks /
-- session_type / scheme and the Hybrid exercise additions). Idempotent:
-- if the template already exists, the whole statement is a no-op.
--
-- Heart-rate zones (running / machines): GREEN 134–154 / 124–144,
-- BLUE 154–164 / 144–154, YELLOW 169–179 / 159–169, ORANGE 179–194 / 169–194,
-- GREY = very easy cooldown.
-- ============================================================================

with const as (
  select 'Warmup: 3 rounds with the empty bar, slow-normal pace — 8 deadlift, 8 strict press or good mornings, 8 back squat, 8 bent-over row. Rest 30–60 s between rounds.

All % is of your 1RM — if the PR is old or you feel beat up, use today''s estimated max. Warm up 2–4 sets before counting work sets. Rest 1–3 min between heavy sets.

The last 1–3 reps of every work set should be properly heavy, nothing left in the tank. Move the weight up or down between sets to keep it that way.'::text as warm
),
prog as (
  insert into public.programs (user_id, name, weeks, days_per_week, active, schedule_mode)
  select null, 'Hybrid Athlete', 20, 5, true, 'fixed'
  where not exists (
    select 1 from public.programs where user_id is null and name = 'Hybrid Athlete')
  returning id
),
wks as (
  insert into public.program_weeks (program_id, week_index, intensity, label, note)
  select prog.id, w.idx, w.intensity, w.label, w.note
  from prog, (values
    (1, 'light', null::text, 'Easier week with less volume — recover from heavy training and keep developing.'::text),
    (2, 'hard', null, 'High amount of training. You will feel tired and not fully recovered — that is the point.'),
    (3, 'medium', null, 'Medium volume — can still feel heavy, especially toward the end of the week.'),
    (4, 'light', null, 'Easier week with less volume — recover and keep developing.'),
    (5, 'medium', null, 'Medium volume — can still feel heavy toward the end of the week.'),
    (6, 'hard', null, 'High amount of training. Tired and under-recovered is expected.'),
    (7, 'light', null, 'Easier week with less volume — recover and keep developing.'),
    (8, 'medium', null, 'Medium volume — can still feel heavy toward the end of the week.'),
    (9, 'hard', null, 'First of two heavy weeks back to back. Push.'),
    (10, 'hard', null, 'Second heavy week in a row — you will not feel fresh. That is by design.'),
    (11, 'light', 'Taper', 'Easier on purpose — recover from the heavy block so next week''s test counts.'),
    (12, 'test', 'Test week', 'Benchmark week — log every result. 1RM: back squat, deadlift, strict press, bench. Max unbroken: strict pull-ups, dips, dead hang. Plus farmers walk distance, a conditioning test and a CrossFit test. These numbers recalibrate every % for the next block.'),
    (13, 'light', null, 'Easy week after testing — new percentages start here.'),
    (14, 'hard', null, 'High amount of training with your fresh maxes. Push.'),
    (15, 'hard', 'Heavy block — conditioning', 'Block week: the order matters. If you must change something, move the rest days first, swap session order second.'),
    (16, 'medium', 'Medium block — CrossFit', 'Block week: the order matters. Move rest days first, swap session order second — only if needed.'),
    (17, 'hard', 'Heavy block — conditioning', 'Block week: the order matters. Move rest days first, swap session order second — only if needed.'),
    (18, 'light', 'Light block — CrossFit', 'Block week, lighter volume. Follow the schedule for the full effect.'),
    (19, 'light', 'Taper', 'Half volume on purpose — arrive at next week''s test fresh. Nothing here should feel like a grind.'),
    (20, 'test', 'Test week — finale', 'Same tests as week 12 — line the numbers up side by side. 20 weeks of work, written down.')
  ) as w(idx, intensity, label, note)
  returning id
),
day_src (week_index, day_index, weekday, name, session_type, content) as (
  values
  -- ---------------------------------------------------------- week 1 · LIGHT
  (1, 1, 1, 'Strict Press & Pull', 'strength', null::text),
  (1, 2, 3, 'Squat & Deadlift', 'strength', null),
  (1, 3, 5, 'AMRAP & Row', 'crossfit', 'Warmup: 5 min easy bike, then 3 rounds (not for time) — 8 cal bike, 8 air squats, 8 walking lunge steps.

1. AMRAP 14 min:
10 air squats
10 push-ups (knees when needed)
10 cal bike

2. For time:
300 m row · 10 box step-ups
300 m row · 20 box step-ups
300 m row · 30 box step-ups
(bodyweight, 60 cm box)

3. Cool down 15–20 min easy bike, HR 100–110.'),
  (1, 4, 7, 'Pull-Ups & Bench', 'strength', 'Rest about 1 min between heavy sets today.'),

  -- ----------------------------------------------------------- week 2 · HEAVY
  (2, 1, 1, 'Bike Intervals — Yellow Zone', 'conditioning', 'Warmup: 5 min green zone + 5 min blue zone bike.

Yellow zone, 2 rounds:
50 cal — rest 2 min
40 cal — rest 1:30
30 cal — rest 1 min
20 cal — rest 30 s
10 cal — rest 2 min
(Assault/Echo bike or BikeErg)

Cool down 15 min easy bike.'),
  (2, 2, 2, 'Heavy Squat & Step-Ups', 'strength', 'Every 90 s × 7: start a running clock, do your reps, rest until the next 90 s mark. Drop the step-up weight only if you must.'),
  (2, 3, 4, 'Lunge & Deadlift Intervals', 'crossfit', 'Warmup: 5 min easy bike, then 3 rounds (not for time) — 6 burpees, 10 walking lunges, 6 DB strict press (easy-moderate).

1. Every 3 min × 8 set (time cap 2:30 per set):
12 steps DB lunge, 2×12.5–17.5 kg
12 push-ups on DBs (knees if needed)
12 DB deadlift, 2×15–17.5 kg
The weights are meant to be heavy and challenging — break up reps as needed.

2. For time, 5 rounds:
20 Russian twists (touch the floor each side)
20 s plank hold

3. Cool down 15–20 min, HR 100–110.'),
  (2, 4, 6, 'Blue Zone Running', 'conditioning', 'Warmup: 5 min green zone running.

10 sets:
3 min blue zone running
1 min rest (walk)

Cool down: walk 5–10 min.

Running gives the best training effect — any conditioning machine works if you can''t run.'),
  (2, 5, 7, 'Deadlift & Bench', 'strength', null),

  -- ---------------------------------------------------------- week 3 · MEDIUM
  (3, 1, 2, 'Press & Push-Ups', 'strength', null),
  (3, 2, 3, 'Bike Intervals — Blue/Yellow', 'conditioning', 'Warmup: 10 min green–blue zone bike.

10 sets (30 min total):
60 s blue zone
90 s yellow zone
30 s rest

Cool down 10–15 min, grey zone.'),
  (3, 3, 5, 'Squat, Deadlift & Hip Thrust', 'strength', null),
  (3, 4, 6, 'Bench & Back', 'strength', null),
  (3, 5, 7, 'Powerwalk', 'conditioning', 'Powerwalk 50–60 min.'),

  -- ----------------------------------------------------------- week 4 · LIGHT
  (4, 1, 1, 'Bike & Kettlebell Engine', 'crossfit', 'Warmup: 5 min easy row, then 2 rounds (not for time) — 5 burpees, 10 Russian KB swings (easy), 10 cal bike.

1. 4 rounds for time:
21 cal bike
15 Russian KB swings, 20 kg (stop at face height)
18 DB push press, 2×15 kg
9 burpees over DB

2. Sit-ups holding a wall ball on your chest: 10–14 reps × 3 set.

3. Cool down 15–20 min, HR 100–110.'),
  (4, 2, 3, 'Zone Intervals — Run or Bike', 'conditioning', 'Pick one:

A) Run: 5 min green zone, then 10 × (3 min blue zone / 1 min walk). Cool down 10 min walking.

B) Bike: 10 min green zone, then blue zone 2:00 / 1:30 / 1:00 / 0:30 on × 5 (30 s rest between), then 15 min blue zone. Cool down 5 min easy.'),
  (4, 3, 4, 'Deadlift & Lunges', 'strength', null),
  (4, 4, 6, 'Close-Grip Bench & Arms', 'strength', null),

  -- ---------------------------------------------------------- week 5 · MEDIUM
  (5, 1, 2, 'Press & Bench Volume', 'strength', null),
  (5, 2, 3, 'Sled & Run', 'crossfit', 'Warmup: 5 min easy bike, then 3 rounds (not for time) — 20 s bike, 5 KB swings (light), 10 m light sled push. Build the sled to a heavy working weight.

1. For time, 5 rounds (cap 30 min):
400 m run
30 m heavy sled push
20 KB swings, 20 kg

2. Cool down on bike 15–20 min, HR 100–120.'),
  (5, 3, 5, 'Squat & Deadlift', 'strength', null),
  (5, 4, 6, 'Green Zone Run', 'conditioning', '50–60 min green zone running — walk whenever you need to stay in the zone. (Swap for padel if you like.)'),
  (5, 5, 7, 'Heavy Press & Pull', 'strength', null),

  -- ----------------------------------------------------------- week 6 · HEAVY
  (6, 1, 2, 'Clean & Jerk Ladder', 'crossfit', 'Warmup: 5 min easy bike, then 5 rounds (not for time) — 20 s bike, 6 box step-ups, 6 DB hang clean & jerk (light).

1. 4 min AMRAP × 5, rest 1 min between:
4 DB hang clean & jerk (alternating), 1×15 kg
4 DB box step-ups, 1×15 kg (50–60 cm)
4 cal bike
…then 6 of each, then 8 — climb by 2 until the 4 min is up. Restart at 4s every AMRAP.

2. GHD sit-ups: 10–12 reps × 5 set (half reps if needed).

3. Cool down 15–20 min, HR 100–110.'),
  (6, 2, 3, 'Blue Zone Running', 'conditioning', 'Warmup: 5–10 min green zone running.

5 × (6 min blue zone / 1 min walk).

Cool down: walk 5–10 min.'),
  (6, 3, 4, 'Squat & Hip Thrust', 'strength', null),
  (6, 4, 5, 'Press & Pull Volume', 'strength', null),
  (6, 5, 7, 'Bench & Arms', 'strength', null),

  -- ----------------------------------------------------------- week 7 · LIGHT
  (7, 1, 1, 'Blue Zone Running', 'conditioning', 'Warmup: 5–10 min green zone running.

5 × (6 min blue zone / 1 min walk).

10 min green zone running to finish.'),
  (7, 2, 3, 'Dumbbell EMOM', 'crossfit', 'Warmup: 5 min easy bike, then 4 rounds (not for time) — 10 cal ski erg, 5 push-ups, 4 DB hang cleans (light).

1. EMOM 24 min:
min 1 — 10 DB bench press
min 2 — 10 DB hang clean
min 3 — 12–15 push-ups
min 4 — 12 bent-over DB rows
Pick a weight you can hold unbroken the first round and keep it all session. If a minute takes over 50 s, go lighter.

2. Cool down on bike 20 min, HR 100–120.'),
  (7, 3, 4, 'Heavy Squat & RDL', 'strength', null),
  (7, 4, 6, 'Press & Pull', 'strength', null),

  -- ---------------------------------------------------------- week 8 · MEDIUM
  (8, 1, 1, 'Ski, Snatch & Row', 'crossfit', 'Warmup: 5 min easy bike, then 4 rounds (not for time) — 6 cal ski erg, 4 wall balls (light), 4 DB snatch (light), 6 cal row.

1. Every 6 min × 5 (cap 5 min per set):
300 m ski erg
16 DB snatch, 1×15 kg
16 wall balls, 6–9 kg
300 m row

2. Cool down on bike 20 min, HR 100–120.'),
  (8, 2, 2, 'Green Zone Run', 'conditioning', '50–60 min green zone running — walking most of it is fine, staying in the zone is the point.'),
  (8, 3, 3, 'Deadlift & Hip Thrust', 'strength', null),
  (8, 4, 5, 'Press & Pull', 'strength', null),
  (8, 5, 6, 'Triple AMRAP', 'crossfit', 'Warmup: 5 min easy bike, then 4 rounds (not for time) — 6 cal bike, 6 walking lunges, 4 DB thrusters (light), 6 cal row.

1. AMRAP 10 min: 12 DB thrusters 2×10 kg · 12 KB swings 20 kg · 12 cal bike
Rest 3 min.
AMRAP 10 min: 12 DB box step-ups 2×10 kg · 12 cal row
Rest 3 min.
AMRAP 10 min: 20 DB walking lunges 2×10 kg · 10 burpees over DB

2. Cool down on bike 20 min, HR 100–120.'),

  -- ----------------------------------------------------------- week 9 · HEAVY
  (9, 1, 1, 'Squat Volume & Step-Ups', 'strength', 'Every 90 s × 7: start a running clock, do your reps, rest until the next 90 s mark.'),
  (9, 2, 2, 'Bench & Arms Volume', 'strength', null),
  (9, 3, 3, 'Blue Zone Run', 'conditioning', 'Warmup: 5 min easy green zone running.

30 min blue zone running. Any machine if you can''t run. (Swap for padel if you like.)'),
  (9, 4, 5, 'Run, Deadlift & Push-Ups', 'crossfit', 'Warmup: 5 min easy bike, then 4 rounds (not for time) — 4 burpees, 250 m run or row, 6 deadlifts (light), 6 push-ups.

1. 5 rounds for time (cap 35 min):
400 m run or row
12 deadlifts, 60 kg
16 hand-release push-ups
20 sit-ups

2. Strict pull-ups: 3–6 reps × 4 set.

3. Cool down on bike 15–20 min, HR 100–110.'),
  (9, 5, 7, 'Squat & Lunges', 'strength', null),

  -- ---------------------------------------------------------- week 10 · HEAVY
  (10, 1, 1, 'Press & Bench 5×5', 'strength', null),
  (10, 2, 2, 'Intervals — Fresh or Worn', 'conditioning', 'Pick by how the body feels.

Fresh: 10 min green–blue bike, then 5 × (60 s blue / 90 s yellow / 30 s rest) on the ski erg, straight into the same 5 sets on the rower. Cool down 15 min easy bike.

Worn: 5–10 min green zone running, then 5 × (6 min blue zone / 1 min walk). Cool down: walk 5–10 min.'),
  (10, 3, 4, 'Wall Balls & Row', 'crossfit', 'Warmup: 5 min easy bike, then 3 rounds (not for time) — 6 cal row, 8 walking lunges, 4 burpees, 6 wall balls (light).

1. For time, 6 rounds (cap 32 min):
20 wall balls, 9 kg
10 burpees over KB
16 KB front-rack lunges, 2×12–16 kg
500 m row

2. EMOM 5 min: 10 GHD sit-ups (half reps if needed).

3. Cool down on bike 15–20 min, HR 100–110.'),
  (10, 4, 5, 'Heavy Press & Pull-Ups', 'strength', null),
  (10, 5, 7, 'Heavy Squat & Deadlift', 'strength', 'Every 90 s × 7: start a running clock, do your reps, rest until the next 90 s mark.'),

  -- ----------------------------------------------- week 11 · LIGHT (taper)
  (11, 1, 2, 'Heavy Triples — Press & Bench', 'strength', null),
  (11, 2, 3, 'Wall Balls & Ski', 'crossfit', 'Warmup: 5 min easy bike, then 4 rounds (not for time) — 4 burpees, 6 walking lunge steps, 6 cal ski erg, 8 air squats.

1. Every 6 min × 5 (cap 5 min per set):
20 wall balls, 9 kg
12 burpees over DB
16 DB front-rack lunges, 2×15 kg
12 cal ski erg

2. Cool down on bike 15–20 min, HR 100–110.'),
  (11, 3, 5, 'Blue Zone Running', 'conditioning', 'Warmup: 5–10 min green zone running.

5 × (6 min blue zone / 1 min walk).

10 min green zone running to finish.'),
  (11, 4, 6, 'Heavy Triples — Squat & Deadlift', 'strength', null),

  -- ------------------------------------------------------------ week 12 · TEST
  (12, 1, 1, 'Test — CrossFit Benchmark', 'crossfit', 'Warmup: 5 min easy bike, then AMRAP 6 min EASY pace — 10 cal row, 10 air squats, 10 push-ups, 10 shoulder circles.

1. TEST — for time (cap 30 min). Note your time, or how far you got at the cap:
1000 m row
80 push press, 20 kg bar
60 KB deadlifts, 2×20 kg
40 DB push press, 2×15 kg
20 burpees over DB

2. TEST — dead hang in the rig: max seconds, 1 attempt. Note it.

3. Cool down on bike 15–20 min, HR 100–110.'),
  (12, 2, 2, 'Green Zone Run (not a test)', 'conditioning', '30 min green zone running — easy, walk as needed. This one is recovery, not a test.'),
  (12, 3, 4, 'Test — 40 min Blue Zone', 'conditioning', 'Warmup: 5 min easy green zone running.

TEST: 40 min blue zone running — note your total distance. Speed doesn''t matter; staying in the zone does. Alternate with walking if you need to hold the zone.'),
  (12, 4, 5, 'Test — Press & Bench 1RM', 'strength', 'Today is for numbers: build to your heaviest single of the day on bench and strict press, then max unbroken pull-ups and dips. Bike 5–10 min easy after the presses before the max-rep tests. Log everything.'),
  (12, 5, 7, 'Test — Squat & Deadlift 1RM', 'strength', 'Build to your heaviest single of the day on squat and deadlift, then the farmers walk distance test. Log everything.'),

  -- ---------------------------------------------------------- week 13 · LIGHT
  (13, 1, 2, '20 min Ski Erg — Blue Zone', 'conditioning', 'Warmup: 5 min green zone + 2 min blue zone ski erg, then 1–2 min rest.

20 min blue zone ski erg — note your total distance. Pace doesn''t matter; holding the zone does.

10 min green zone ski or run to finish.'),
  (13, 2, 3, 'Push Press & Run', 'crossfit', 'Warmup: 2 rounds (not for time) — 10 burpees, 10 sit-ups, 12 walking lunges.

1. 5 rounds for time:
15 DB push press, 2×20 kg
400 m run
20 thrusters (empty bar) or wall balls 9 kg
10 burpees
Nothing needs to be unbroken — split reps whenever you need.

2. Cool down 15–20 min, HR 100–110.'),
  (13, 3, 5, 'Bench, Pull-Ups & Dips', 'strength', 'EMOM 12 on the dips pairing: odd minutes dips, even minutes leg raises — rest whatever remains of each minute.'),
  (13, 4, 7, 'Squat & Deadlift', 'strength', null),

  -- ---------------------------------------------------------- week 14 · HEAVY
  (14, 1, 1, 'Bench & Press 5×5', 'strength', null),
  (14, 2, 3, 'Ski Erg Intervals', 'conditioning', 'Warmup: 10 min green–blue zone ski erg.

8 × (500 m yellow zone ski erg / 90 s rest).

10 min green–blue zone ski erg, then 10 min walking cool down.'),
  (14, 3, 5, 'Squat & Deadlift 6×5', 'strength', null),
  (14, 4, 6, 'Long Blue Run', 'conditioning', 'Warmup: 10 min green zone running.

2 × (3 km blue zone / 1 min walk), then 1 × 2 km blue zone.

10 min green zone running, walk 5 min to finish.'),

  -- ------------------------------------ week 15 · HEAVY BLOCK (conditioning)
  (15, 1, 1, 'Yellow Zone Run Intervals', 'conditioning', 'Warmup: 10 min blue zone running.

5 × (4 min yellow zone / 2 min rest).

Cool down: walk 10–15 min. Any machine if you can''t run.'),
  (15, 2, 2, 'Deadlift & Snatch Triplet', 'crossfit', 'Warmup: 3 rounds (not for time) — 10 box step-ups, 10 KB swings (easy), 10 air squats. Build your deadlift to working weight.

1. 21-15-9 reps: deadlift 70 kg · burpees over bar · sit-ups
Rest 5 min.
20-15-10 reps: push-ups · DB box step-ups, 1×20 kg (50–60 cm)
Rest 5 min.
5 rounds: 10 DB snatch 1×20 kg (alternating) · 10 cal ski erg

2. Cool down 15–20 min easy bike, grey zone — it speeds up recovery.'),
  (15, 3, 3, 'Blue Zone Running', 'conditioning', 'Warmup: 5–10 min green zone running.

5 × (6 min blue zone / 1 min walk).

10 min green zone running to finish.'),
  (15, 4, 5, 'Bench & Push Press Density', 'crossfit', 'Warmup: 5 min easy bike, then 3 rounds (not for time) — 6 burpees, 7 cal bike, 5 strict press + 5 push press (empty bar). Build your bench to working weight.

1. 10 rounds: 3 bench press, 50 kg + 3 dips on the bar.

2. 10-9-8-…-1 reps for time: push press @ 80–85% of your strict press 1RM, with 8 cal ski erg between rounds. Split the reps as much as you need.

3. Cool down 15–20 min easy bike, grey zone.'),
  (15, 5, 6, 'Green Zone Run', 'conditioning', '50–60 min green zone running — any machine if you can''t run.'),

  -- ---------------------------------------- week 16 · MEDIUM BLOCK (CrossFit)
  (16, 1, 1, 'Push Press & Sandbag', 'crossfit', 'Warmup: 3 rounds (not for time) — 300 m run or row, 5 burpees, 6 DB push press (light).

1. 3 rounds for time: 30 DB push press 2×15 kg · 400 m run or row

2. AMRAP 12 min:
7 V-ups or GHD sit-ups
20 m walking lunges, 2×15 kg (10 m sections)
5 sandbag cleans, 40 kg

3. Cool down 15–20 min, HR 100–110.'),
  (16, 2, 2, 'Ski, Shuttles & Deadlift', 'crossfit', 'Warmup: 3 rounds (not for time) — 200 m ski erg, 2 shuttle runs, 5 deadlifts 40–70 kg.

1. For time:
1000 m ski erg · 10 shuttle runs (7.5+7.5 m) · 10 deadlifts 70 kg
800 m ski erg · 8 shuttle runs · 10 deadlifts 70 kg
600 m ski erg · 6 shuttle runs · 10 deadlifts 70 kg

2. Cool down 15–20 min, HR 100–110.'),
  (16, 3, 3, 'Bike & Back Squat', 'crossfit', 'Warmup: 5 min easy bike, then 3 rounds (not for time) — 8 cal bike, 8 back squats (empty bar), 8 bent-over rows (empty bar). Build your squat to working weight.

1. For time: 30 cal bike · 30 back squats 40 kg · 30 cal bike

2. AMRAP 15 min:
9 DB snatch right arm, 17.5 kg
9 DB snatch left arm
9 burpees to plate (10–15 cm)
9 cal ski erg

3. Cool down on bike 15–20 min, HR 100–110.'),
  (16, 4, 5, 'Blue Zone Running', 'conditioning', 'Warmup: 5–10 min green zone running.

5 × (6 min blue zone / 1 min walk).

10 min green zone running to finish.'),
  (16, 5, 6, 'RDL & Farmers Walk', 'strength', null),

  -- ------------------------------------ week 17 · HEAVY BLOCK (conditioning)
  (17, 1, 1, 'Zone Pyramid Run', 'conditioning', 'Warmup: 5 min green zone running.

20 min blue zone — rest 3 min (walk) —
10 min yellow zone — rest 3 min (walk) —
5 min orange zone.

Cool down 10–15 min, grey zone.'),
  (17, 2, 3, '800s — Yellow Zone', 'conditioning', 'Warmup: 10 min green–blue zone running.

8 × (800 m yellow zone / 90 s rest, walk).

10 min green–blue zone running, then 5–10 min walking.'),
  (17, 3, 4, 'Squat + Push Press Complex', 'strength', 'The complex: 3 back squats then 3 push press without dropping the bar = one set.'),
  (17, 4, 5, 'Long Green Run', 'conditioning', '60 min green zone running — walk as needed to hold the zone. Any machine if you can''t run.'),
  (17, 5, 6, 'Push Press & KB Deadlift', 'crossfit', 'Warmup: 4 rounds (not for time) — 6 cal ski erg, 6 burpees, 6 air squats, 6 DB push press (light).

1. For time, 4 rounds:
15 DB push press, 2×15–17.5 kg
15 cal ski erg
25 sit-ups
15 cal ski erg

2. For time, 20-15-10 reps:
KB deadlift, 2×24 kg
burpees over KB
calories row

3. Cool down 15–20 min.'),

  -- ----------------------------------------- week 18 · LIGHT BLOCK (CrossFit)
  (18, 1, 1, 'Dips, Row & Wall Balls', 'crossfit', 'Warmup: EMOM 5 min — 4 burpees, 4 wall balls (easy), row the rest of the minute at an easy pace.

1. Every 90 s × 5: 6–10 dips on the bar.

2. Every 5 min × 4 (cap 4 min per set):
20 cal row
25 wall balls, 9 kg
5 burpee pull-ups

3. Cool down 15–20 min, HR 100–110.'),
  (18, 2, 2, 'Deadlift & Devils Press', 'crossfit', 'Warmup: 4 rounds (not for time) — 8 cal any machine, 6 push-ups, 4 devils press (light), 8 Romanian deadlifts (empty bar, slow, feel the stretch). Build your deadlift to working weight.

1. 21-15-9 reps for time: deadlifts 60 kg · burpees over bar
Straight into 10-9-8-…-1 reps: devils press, 1×15 kg (switch arm every rep), with 8 cal bike between sets.

2. Cool down 15–20 min, HR 100–110.'),
  (18, 3, 4, 'Big Three Triples', 'strength', null),
  (18, 4, 5, 'Hundreds + Blue Run', 'crossfit', 'One continuous session — short rest between the parts.

Warmup: 3 rounds at warmup pace — 10 air squats, 5 push-ups, 6 sit-ups.

1. For time: 100 push-ups · 100 sit-ups · 100 air squats

2. Run: 5–10 min green zone, then 4 × (6 min blue zone / 1 min walk). Cool down 10–15 min walking.'),

  -- ----------------------------------------------- week 19 · LIGHT (taper)
  (19, 1, 2, 'Sharp Triples — Press & Bench', 'strength', null),
  (19, 2, 3, 'Easy Blue Run', 'conditioning', 'Warmup: 5–10 min green zone running.

4 × (6 min blue zone / 1 min walk).

Cool down: walk 10 min. Keep it comfortable — this is a taper.'),
  (19, 3, 5, 'Technique EMOM — Yellow Pace', 'crossfit', 'Yellow intensity: technique pace, no lactate. Warmup: 5 min easy bike, then 4 rounds (not for time) — 10 cal ski erg, 5 push-ups, 4 DB hang cleans (light).

1. EMOM 16 min:
min 1 — 8 DB bench press
min 2 — 8 DB hang clean
min 3 — 10 push-ups
min 4 — 10 bent-over DB rows
Lighter than week 7 — every minute should finish by 40 s.

2. Cool down on bike 15 min, HR 100–110.'),
  (19, 4, 6, 'Sharp Triples — Squat & Deadlift', 'strength', null),

  -- ------------------------------------------------------------ week 20 · TEST
  (20, 1, 1, 'Test — CrossFit Benchmark', 'crossfit', 'Same workout as week 12 — race your old time.

Warmup: 5 min easy bike, then AMRAP 6 min EASY pace — 10 cal row, 10 air squats, 10 push-ups, 10 shoulder circles.

1. TEST — for time (cap 30 min). Note your time, or how far you got at the cap:
1000 m row
80 push press, 20 kg bar
60 KB deadlifts, 2×20 kg
40 DB push press, 2×15 kg
20 burpees over DB

2. TEST — dead hang in the rig: max seconds, 1 attempt. Note it.

3. Cool down on bike 15–20 min, HR 100–110.'),
  (20, 2, 2, 'Green Zone Run (not a test)', 'conditioning', '30 min green zone running — easy, walk as needed. This one is recovery, not a test.'),
  (20, 3, 4, 'Test — 40 min Blue Zone', 'conditioning', 'Warmup: 5 min easy green zone running.

TEST: 40 min blue zone running — note your total distance and compare it with week 12.'),
  (20, 4, 5, 'Test — Press & Bench 1RM', 'strength', 'Same tests as week 12 — put the numbers side by side. Build to your heaviest single on bench and strict press, then max unbroken pull-ups and dips. Bike 5–10 min easy after the presses. Log everything.'),
  (20, 5, 7, 'Test — Squat & Deadlift 1RM', 'strength', 'Same tests as week 12. Build to your heaviest single on squat and deadlift, then the farmers walk distance test. Log everything.')
),
days as (
  insert into public.program_days
    (program_id, week_index, day_index, weekday, name, session_type, content)
  select prog.id, s.week_index, s.day_index, s.weekday, s.name, s.session_type,
         case when s.session_type = 'strength'
              then (select warm from const)
                   || coalesce(chr(10) || chr(10) || s.content, '')
              else s.content end
  from prog, day_src s
  returning id, week_index, day_index
)
insert into public.program_exercises (program_day_id, exercise_id, sort, sets, scheme)
select d.id, e.id, x.sort, x.sets, x.scheme
from days d
join (values
  -- week 1 · day 1 — Strict Press & Pull
  (1, 1, 1, 'Overhead Press', 3, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 3 set'),
  (1, 1, 2, 'Barbell Row', 3, '12 reps light · 12 reps medium · 10 reps × 3 heavy set'),
  (1, 1, 3, 'Strict Pull-Up', 3, 'Band as needed · 2–4 reps × 3 set'),
  (1, 1, 4, 'Lat Pulldown', 3, '12–14 reps × 3 set'),
  -- week 1 · day 2 — Squat & Deadlift
  (1, 2, 1, 'Back Squat', 3, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 3 set'),
  (1, 2, 2, 'Conventional Deadlift', 3, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 3 set'),
  (1, 2, 3, 'Leg Extension', 4, '10–12 reps × 4 set'),
  (1, 2, 4, 'Lying Leg Curl', 4, '10–12 reps × 4 set'),
  -- week 1 · day 4 — Pull-Ups & Bench
  (1, 4, 1, 'Strict Pull-Up', 4, 'Band as needed · 2–4 reps × 4 set — last reps really heavy'),
  (1, 4, 2, 'Dumbbell Bench Press', 4, '10 reps × 4 set'),
  (1, 4, 3, 'Machine Chest Press', 3, '12–14 reps × 3 set'),
  (1, 4, 4, 'Face Pull', 3, '14–16 reps × 3 set'),
  (1, 4, 5, 'Cable Crunch', 3, 'Kneeling · 12–15 reps × 3 set'),
  -- week 2 · day 2 — Heavy Squat & Step-Ups
  (2, 2, 1, 'Back Squat', 5, 'Ramp 20–70% 5×3 · 70–80% 4×3, then work 80–90% · 3 reps × 5 set'),
  (2, 2, 2, 'Bulgarian Split Squat', 4, '2×DB · 8–12 reps × 4 set each leg'),
  (2, 2, 3, 'Lying Leg Curl', 4, '12 light · 12 medium · 12 reps × 4 heavy set'),
  (2, 2, 4, 'Step-Ups', 7, 'Every 90 s × 7 set — 5–7 reps, 2×10–15 kg DBs, 50 cm box'),
  -- week 2 · day 5 — Deadlift & Bench
  (2, 5, 1, 'Conventional Deadlift', 5, 'Ramp 20–69% · 6 reps × 3 set, then work 70–79% · 5 reps × 5 set'),
  (2, 5, 2, 'Barbell Bench Press', 5, 'Ramp 20–69% · 6 reps × 3 set, then work 70–80% · 5 reps × 5 set'),
  (2, 5, 3, 'Seal Row', 6, 'Wide grip 12–14 reps × 3 set, then close grip 8–12 reps × 3 set'),
  (2, 5, 4, 'Lat Pulldown', 4, '12–14 reps × 4 set'),
  -- week 3 · day 1 — Press & Push-Ups
  (3, 1, 1, 'Overhead Press', 4, 'Ramp 20–70% · 5 reps × 4 set, then work 70–80% · 5 reps × 4 set'),
  (3, 1, 2, 'Strict Pull-Up', 4, 'Band as needed · 2–5 reps × 4 set — last reps really heavy'),
  (3, 1, 3, 'Dumbbell Bench Press', 4, '10–12 reps × 4 set'),
  (3, 1, 4, 'Lateral Raises', 4, 'Standing · 14–16 reps × 4 set'),
  (3, 1, 5, 'Push-Up', 4, 'Chest and thighs to the floor · max reps to failure × 4 set'),
  -- week 3 · day 3 — Squat, Deadlift & Hip Thrust
  (3, 3, 1, 'Back Squat', 6, 'Ramp 20–50% 6×2 · 50–60% 6×2, then work 60–69% · 6 reps × 6 set (last 1–2 reps really heavy)'),
  (3, 3, 2, 'Conventional Deadlift', 4, 'Ramp 20–70% · 5 reps × 4 set, then work 70–80% · 5 reps × 4 set'),
  (3, 3, 3, 'Hip Thrust', 5, 'Pause 1 s at the top · 6–8 reps × 5 heavy set'),
  (3, 3, 4, 'Side Plank', 6, '15 s hold / 15 s rest × 6 set per side'),
  -- week 3 · day 4 — Bench & Back
  (3, 4, 1, 'Barbell Bench Press', 4, 'Ramp 20–70% · 5 reps × 4 set, then work 70–80% · 5 reps × 4 set'),
  (3, 4, 2, 'Seal Row', 5, 'Wide grip · 10–12 reps × 5 set'),
  (3, 4, 3, 'Seated Cable Row', 3, '10–12 reps × 3 set'),
  (3, 4, 4, 'Machine Chest Press', 4, '12 reps × 4 set'),
  (3, 4, 5, 'Lat Pulldown', 4, '12 reps × 4 set'),
  -- week 4 · day 3 — Deadlift & Lunges
  (4, 3, 1, 'Conventional Deadlift', 3, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 3 set'),
  (4, 3, 2, 'Walking Lunges', 3, '2×DB · 20 m × 3 heavy set (or 25 steps)'),
  (4, 3, 3, 'Hip Thrust', 3, 'Pause 1 s at the top · 8 light · 8 medium · 8 reps × 3 heavy set'),
  (4, 3, 4, 'Leg Extension', 3, '12 reps × 3 set'),
  -- week 4 · day 4 — Close-Grip Bench & Arms
  (4, 4, 1, 'Close-Grip Bench Press', 3, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 3 set'),
  (4, 4, 2, 'Strict Pull-Up', 3, 'Band as needed · 2–4 reps × 3 set'),
  (4, 4, 3, 'Barbell Curl', 4, '12–14 reps × 4 set'),
  (4, 4, 4, 'Single-Arm Dumbbell Row', 3, '12–14 reps × 3 set each arm'),
  (4, 4, 5, 'Side Plank', 8, '20 s hold / 10 s rest × 8 set per side'),
  -- week 5 · day 1 — Press & Bench Volume
  (5, 1, 1, 'Overhead Press', 4, 'Ramp 20–60% · 7 reps × 2 set, then work 60–69% · 6 reps × 4 set'),
  (5, 1, 2, 'Barbell Bench Press', 4, 'Ramp 20–60% · 7 reps × 2 set, then work 60–69% · 6 reps × 4 set'),
  (5, 1, 3, 'Seal Row', 4, '12–15 reps × 4 set'),
  (5, 1, 4, 'Lat Pulldown', 4, '12–14 reps × 4 set'),
  -- week 5 · day 3 — Squat & Deadlift
  (5, 3, 1, 'Back Squat', 4, 'Ramp 20–70% · 6 reps × 3 set, then work 70–80% · 5 reps × 4 set'),
  (5, 3, 2, 'Conventional Deadlift', 4, 'Ramp 20–70% · 6 reps × 3 set, then work 70–80% · 5 reps × 4 set'),
  (5, 3, 3, 'Bulgarian Split Squat', 4, '8–12 reps × 4 set each leg'),
  (5, 3, 4, 'Leg Extension', 4, '12–14 reps × 4 set'),
  (5, 3, 5, 'Dead Bug', 8, 'Slow, controlled · 20 s work / 10 s rest × 8 set'),
  -- week 5 · day 5 — Heavy Press & Pull
  (5, 5, 1, 'Overhead Press', 4, 'Ramp 20–70% 4×3 · 70–80% 4×2, then work 80–90% · 3 reps × 4 set'),
  (5, 5, 2, 'Weighted Pull-Up', 4, 'Heavy · 2–4 reps × 4 set'),
  (5, 5, 3, 'Weighted Dip', 4, 'Add weight if you can · 3–6 reps × 4 set'),
  (5, 5, 4, 'Lateral Raises', 4, '12–14 reps × 4 set'),
  (5, 5, 5, 'Overhead Cable Triceps Extension', 4, 'Cable or barbell · 8–12 reps × 4 set'),
  -- week 6 · day 3 — Squat & Hip Thrust
  (6, 3, 1, 'Back Squat', 5, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 5 set'),
  (6, 3, 2, 'Hip Thrust', 5, '6–8 reps × 5 set'),
  (6, 3, 3, 'Bulgarian Split Squat', 5, '1×DB · 8–12 reps × 5 set each leg'),
  (6, 3, 4, 'Back Extension', 5, 'GHD · pause 1 s at the top · 12–15 reps × 5 set'),
  -- week 6 · day 4 — Press & Pull Volume
  (6, 4, 1, 'Overhead Press', 5, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 5 set'),
  (6, 4, 2, 'Barbell Row', 5, '8–12 reps × 5 set'),
  (6, 4, 3, 'Weighted Pull-Up', 5, 'Heavy · 2–4 reps × 5 set'),
  (6, 4, 4, 'Lat Pulldown', 4, '12–14 reps × 4 set'),
  (6, 4, 5, 'Side Plank', 6, 'EMOM 6 min — odd: 45 s right side, even: 45 s left side'),
  -- week 6 · day 5 — Bench & Arms
  (6, 5, 1, 'Barbell Bench Press', 5, 'Ramp 20–69% · 6 reps × 3 set, then work 70–79% · 5 reps × 5 set'),
  (6, 5, 2, 'Lateral Raises', 4, '12–15 reps × 4 set'),
  (6, 5, 3, 'Overhead Cable Triceps Extension', 4, 'Cable or barbell · 12–15 reps × 4 set'),
  (6, 5, 4, 'Barbell Curl', 4, '12–15 reps × 4 set'),
  -- week 7 · day 3 — Heavy Squat & RDL
  (7, 3, 1, 'Back Squat', 4, 'Ramp 20–70% 4×3 · 70–80% 4×2, then work 80–90% · 3 reps × 4 set'),
  (7, 3, 2, 'Romanian Deadlift', 4, '6–8 reps × 4 set'),
  (7, 3, 3, 'Leg Extension', 4, '8–12 reps × 4 set'),
  (7, 3, 4, 'Back Extension', 3, 'GHD · pause 1 s at the top · 15–20 reps × 3 set'),
  -- week 7 · day 4 — Press & Pull
  (7, 4, 1, 'Overhead Press', 4, 'Ramp 20–60% · 6 reps × 3 set, then work 70–75% · 6 reps × 4 set'),
  (7, 4, 2, 'Weighted Pull-Up', 4, 'Heavy · 2–4 reps × 4 set'),
  (7, 4, 3, 'Seal Row', 3, '12–14 reps × 3 set'),
  (7, 4, 4, 'Overhead Cable Triceps Extension', 3, 'Cable or DB · 8–12 reps × 3 set'),
  (7, 4, 5, 'Side Plank', 6, 'EMOM 6 min — odd: 45 s right side, even: 45 s left side'),
  -- week 8 · day 3 — Deadlift & Hip Thrust
  (8, 3, 1, 'Conventional Deadlift', 4, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 4 set'),
  (8, 3, 2, 'Walking Lunges', 4, '2×DB · 10 m × 4 set'),
  (8, 3, 3, 'Hip Thrust', 4, 'Pause 1 s at the top · 6–8 reps × 4 set'),
  (8, 3, 4, 'Leg Extension', 4, '10–12 reps × 4 set'),
  -- week 8 · day 4 — Press & Pull
  (8, 4, 1, 'Overhead Press', 4, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 4 set'),
  (8, 4, 2, 'Barbell Row', 4, '8–12 reps × 4 set'),
  (8, 4, 3, 'Weighted Pull-Up', 4, 'Heavy · 2–4 reps × 4 set'),
  (8, 4, 4, 'Lat Pulldown', 4, '12–14 reps × 4 set'),
  (8, 4, 5, 'Dead Bug', 8, 'Slow, controlled · 20 s work / 10 s rest × 8 set'),
  -- week 9 · day 1 — Squat Volume & Step-Ups
  (9, 1, 1, 'Back Squat', 5, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 5 set'),
  (9, 1, 2, 'Romanian Deadlift', 5, '6–8 reps × 5 set'),
  (9, 1, 3, 'Bulgarian Split Squat', 5, '1×DB · 8–12 reps × 5 set each leg'),
  (9, 1, 4, 'Step-Ups', 7, 'Every 90 s × 7 set — 10 reps (5 per leg), 2×DB, 50–60 cm box'),
  -- week 9 · day 2 — Bench & Arms Volume
  (9, 2, 1, 'Barbell Bench Press', 5, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 5 set'),
  (9, 2, 2, 'Overhead Cable Triceps Extension', 5, 'Cable or barbell · 8–12 reps × 5 set'),
  (9, 2, 3, 'Push-Up', 4, 'Close grip, hands on a bench · max unbroken reps × 4 set'),
  (9, 2, 4, 'Skullcrushers', 4, 'Plate triceps extension · 12–14 reps × 4 set'),
  (9, 2, 5, 'Barbell Curl', 4, '12–15 reps × 4 set'),
  -- week 9 · day 5 — Squat & Lunges
  (9, 5, 1, 'Back Squat', 5, 'Ramp 20–60% · 6 reps × 3 set, then work 60–75% · 6 reps × 5 set'),
  (9, 5, 2, 'Walking Lunges', 5, '2×DB · 10 m × 5 set'),
  (9, 5, 3, 'Leg Extension', 4, '10–12 reps × 4 set'),
  (9, 5, 4, 'Lying Leg Curl', 4, 'Pause 1 s at the bottom · 10–12 reps × 4 set'),
  -- week 10 · day 1 — Press & Bench 5×5
  (10, 1, 1, 'Overhead Press', 5, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 5 set'),
  (10, 1, 2, 'Barbell Bench Press', 5, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 5 set'),
  (10, 1, 3, 'Seal Row', 4, 'Wide grip · 8–10 reps × 4 set'),
  (10, 1, 4, 'Lat Pulldown', 4, '10–12 reps × 4 set'),
  (10, 1, 5, 'Seated Cable Row', 3, '10–12 reps × 3 set'),
  -- week 10 · day 4 — Heavy Press & Pull-Ups
  (10, 4, 1, 'Overhead Press', 4, 'Ramp 20–70% 4×3 · 70–80% 4×2, then work 80–90% · 3 reps × 4 set'),
  (10, 4, 2, 'Weighted Pull-Up', 5, 'Heavy · 2–4 reps × 5 set'),
  (10, 4, 3, 'Lateral Raises', 4, '12–14 reps × 4 set'),
  (10, 4, 4, 'Lat Pulldown', 4, '12–14 reps × 4 set'),
  (10, 4, 5, 'Dead Bug', 8, 'Slow, controlled · 20 s work / 10 s rest × 8 set'),
  -- week 10 · day 5 — Heavy Squat & Deadlift
  (10, 5, 1, 'Back Squat', 4, 'Ramp 20–70% 4×3 · 70–80% 4×2, then work 80–90% · 3 reps × 4 set'),
  (10, 5, 2, 'Conventional Deadlift', 4, 'Ramp 20–70% 4×3 · 70–80% 4×2, then work 80–90% · 3 reps × 4 set'),
  (10, 5, 3, 'Step-Ups', 7, 'Every 90 s × 7 set — 10 reps (5 per leg), 2×DB, 50–60 cm box'),
  (10, 5, 4, 'Back Extension', 5, 'GHD · pause 1 s at the top · 15–20 reps × 5 set'),
  -- week 11 · day 1 — Heavy Triples — Press & Bench
  (11, 1, 1, 'Overhead Press', 4, 'Ramp 20–70% 4×3 · 70–80% 4×2, then work 80–90% · 3 reps × 4 set'),
  (11, 1, 2, 'Barbell Bench Press', 4, 'Ramp 20–70% 4×3 · 70–80% 4×2, then work 80–90% · 3 reps × 4 set'),
  (11, 1, 3, 'Overhead Cable Triceps Extension', 3, 'Cable or barbell · 8–12 reps × 3 set'),
  (11, 1, 4, 'Push-Up', 3, 'Close grip, hands on a bench · max unbroken reps × 3 set'),
  (11, 1, 5, 'Barbell Row', 3, '10–14 reps × 3 set'),
  -- week 11 · day 4 — Heavy Triples — Squat & Deadlift
  (11, 4, 1, 'Back Squat', 3, 'Ramp 20–70% 3×3 · 70–80% 3×2, then work 80–90% · 3 reps × 3 set'),
  (11, 4, 2, 'Conventional Deadlift', 3, 'Ramp 20–70% 3×3 · 70–80% 3×2, then work 80–90% · 3 reps × 3 set'),
  (11, 4, 3, 'Barbell Bench Press', 3, 'Ramp 20–70% · 6 reps × 3 set, then work 70–80% · 5 reps × 3 set'),
  (11, 4, 4, 'Lat Pulldown', 3, '10–12 reps × 3 set'),
  -- week 12 · day 4 — Test — Press & Bench 1RM
  (12, 4, 1, 'Barbell Bench Press', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — build to your heaviest single. Log the top weight.'),
  (12, 4, 2, 'Overhead Press', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — log the top weight.'),
  (12, 4, 3, 'Strict Pull-Up', 1, 'TEST · 2 easy warmup sets, then max unbroken reps × 1 — log the reps.'),
  (12, 4, 4, 'Weighted Dip', 1, 'TEST · 2 easy warmup sets, then max unbroken reps × 1 (bodyweight) — log the reps.'),
  -- week 12 · day 5 — Test — Squat & Deadlift 1RM
  (12, 5, 1, 'Back Squat', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — log the top weight.'),
  (12, 5, 2, 'Conventional Deadlift', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — log the top weight.'),
  (12, 5, 3, 'Farmers Walk', 1, 'TEST · 2×24 kg — max unbroken distance × 1. Measure a 10–15 m stretch, count lengths, log total meters as reps.'),
  -- week 13 · day 3 — Bench, Pull-Ups & Dips
  (13, 3, 1, 'Strict Pull-Up', 4, 'Pull as high as you can each rep · max unbroken reps × 4 set'),
  (13, 3, 2, 'Barbell Bench Press', 3, 'Ramp 20–70% · 5 reps × 3 set, then work 70–82% · 5 reps × 3 set'),
  (13, 3, 3, 'Bicep Curls', 4, 'Seated, curl into strict press · 12 alternating reps × 4 set'),
  (13, 3, 4, 'Weighted Dip', 6, 'EMOM 12 — odd: 7 dips (weighted if you can), even: 8–12 leg raises in the rig'),
  -- week 13 · day 4 — Squat & Deadlift
  (13, 4, 1, 'Back Squat', 3, 'Ramp 20–70% · 5 reps × 3 set, then work 70–82% · 5 reps × 3 set'),
  (13, 4, 2, 'Conventional Deadlift', 3, 'Ramp 20–70% · 5 reps × 3 set, then work 70–82% · 5 reps × 3 set'),
  (13, 4, 3, 'Bulgarian Split Squat', 3, '2×DB · 8–12 reps × 3 heavy set each leg'),
  -- week 14 · day 1 — Bench & Press 5×5
  (14, 1, 1, 'Barbell Bench Press', 5, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 5 set'),
  (14, 1, 2, 'Overhead Press', 5, 'Ramp 20–70% · 5 reps × 3 set, then work 70–80% · 5 reps × 5 set'),
  (14, 1, 3, 'Lat Pulldown', 3, '10–12 reps × 3 set'),
  (14, 1, 4, 'Weighted Dip', 3, 'Add weight · 5–7 reps × 3 set'),
  (14, 1, 5, 'Face Pull', 3, '10–14 reps × 3 set'),
  -- week 14 · day 3 — Squat & Deadlift 6×5
  (14, 3, 1, 'Back Squat', 5, 'Ramp 20–70% · 6 reps × 3 set, then work 70–80% · 6 reps × 5 set'),
  (14, 3, 2, 'Conventional Deadlift', 5, 'Ramp 20–70% · 6 reps × 3 set, then work 70–80% · 6 reps × 5 set'),
  (14, 3, 3, 'Bulgarian Split Squat', 5, '2×DB · 10–12 reps × 5 set each leg'),
  -- week 16 · day 5 — RDL & Farmers Walk
  (16, 5, 1, 'Romanian Deadlift', 4, '7 reps × 3 light · 7 × 3 medium, then work 5 reps × 4 heavy set'),
  (16, 5, 2, 'Close-Grip Bench Press', 4, 'Ramp 20–69% 3×3 · 70–79% 3×2, then work 80–90% · 3 reps × 4 set'),
  (16, 5, 3, 'Weighted Pull-Up', 4, 'Add weight · 2–4 reps × 4 set'),
  (16, 5, 4, 'Farmers Walk', 5, 'Single-arm, slow walk, straight back · 40 m × 5 set per arm (same weight both arms, 24–32 kg KB) · rest 30 s'),
  -- week 17 · day 3 — Squat + Push Press Complex
  (17, 3, 1, 'Push Press', 8, 'Complex with back squat — 3 squats + 3 push press per set · 4 set light-medium + 4 set heavy'),
  (17, 3, 2, 'Back Squat', 4, 'Ramp 20–60% 4×3 · 60–70% 4×2, then work 70–82% · 4 reps × 4 set'),
  (17, 3, 3, 'Close-Grip Bench Press', 4, 'Ramp 20–60% 4×3 · 60–70% 4×2, then work 70–82% · 4 reps × 4 set'),
  (17, 3, 4, 'Weighted Pull-Up', 5, 'Add weight · 2–4 reps × 5 set'),
  -- week 18 · day 3 — Big Three Triples
  (18, 3, 1, 'Back Squat', 9, '3 reps × 3 set @ 20–69% · × 3 @ 70–79% · × 3 @ 80–89%'),
  (18, 3, 2, 'Barbell Bench Press', 9, '3 reps × 3 set @ 20–69% · × 3 @ 70–79% · × 3 @ 80–89%'),
  (18, 3, 3, 'Overhead Press', 9, '3 reps × 3 set @ 20–69% · × 3 @ 70–79% · × 3 @ 80–89%'),
  (18, 3, 4, 'Barbell Curl', 3, '20 kg bar · max unbroken controlled reps × 3 set'),
  -- week 19 · day 1 — Sharp Triples — Press & Bench
  (19, 1, 1, 'Overhead Press', 3, 'Ramp 20–70% 3×3 · 70–80% 3×2, then sharp work 80–88% · 3 reps × 3 set'),
  (19, 1, 2, 'Barbell Bench Press', 3, 'Ramp 20–70% 3×3 · 70–80% 3×2, then sharp work 80–88% · 3 reps × 3 set'),
  (19, 1, 3, 'Overhead Cable Triceps Extension', 2, '8–12 reps × 2 set'),
  (19, 1, 4, 'Barbell Row', 2, '10–14 reps × 2 set'),
  -- week 19 · day 4 — Sharp Triples — Squat & Deadlift
  (19, 4, 1, 'Back Squat', 3, 'Ramp 20–70% 3×3 · 70–80% 3×2, then sharp work 80–88% · 3 reps × 3 set'),
  (19, 4, 2, 'Conventional Deadlift', 3, 'Ramp 20–70% 3×3 · 70–80% 3×2, then sharp work 80–88% · 3 reps × 3 set'),
  (19, 4, 3, 'Lat Pulldown', 3, '10–12 reps × 3 set'),
  -- week 20 · day 4 — Test — Press & Bench 1RM
  (20, 4, 1, 'Barbell Bench Press', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — log the top weight and compare with week 12.'),
  (20, 4, 2, 'Overhead Press', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — log the top weight and compare with week 12.'),
  (20, 4, 3, 'Strict Pull-Up', 1, 'TEST · 2 easy warmup sets, then max unbroken reps × 1 — log the reps.'),
  (20, 4, 4, 'Weighted Dip', 1, 'TEST · 2 easy warmup sets, then max unbroken reps × 1 (bodyweight) — log the reps.'),
  -- week 20 · day 5 — Test — Squat & Deadlift 1RM
  (20, 5, 1, 'Back Squat', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — log the top weight and compare with week 12.'),
  (20, 5, 2, 'Conventional Deadlift', 5, 'TEST · 3 reps × 3 light, 2 × 2 medium, then 1 rep × 5 attempts — log the top weight and compare with week 12.'),
  (20, 5, 3, 'Farmers Walk', 1, 'TEST · 2×24 kg — max unbroken distance × 1, same stretch as week 12. Log total meters as reps.')
) as x(week_index, day_index, sort, exercise_name, sets, scheme)
  on x.week_index = d.week_index and x.day_index = d.day_index
join public.exercises e on e.name = x.exercise_name and e.is_global;
