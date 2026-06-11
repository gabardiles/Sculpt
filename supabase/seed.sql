-- Sculpt — seed data: global exercise library, the "Lean & Sculpted" template
-- program, and pep quotes. Run AFTER all migrations (the rep_profile column
-- comes from 0004). Safe on a fresh database.
--
-- rep_profile drives phase rep targets: 'strength' waves 10–12/6–8/4–6,
-- 'pump' waves 15–20/12–15/10–12, 'timed' waves hold seconds 30/40/45.
--
-- instruction_url is seeded by 0003_instruction_videos.sql where curated
-- videos exist; the UI shows the form cue either way.

-- ------------------------------------------------------------ exercises
insert into public.exercises (name, short_label, muscle_group, movement_pattern, equipment, unit, rep_profile, cue, is_global) values
-- hinge · hamstrings
('Romanian Deadlift', 'RDL', 'hamstrings', 'hinge', 'barbell', 'kg', 'strength', 'Soft knees, push hips back until the hamstrings load. Bar drags up your legs.', true),
('Dumbbell Romanian Deadlift', 'DB RDL', 'hamstrings', 'hinge', 'dumbbells', 'kg', 'strength', 'Hips back, flat back. Dumbbells slide down the front of your thighs.', true),
('Single-Leg Romanian Deadlift', 'SL RDL', 'hamstrings', 'hinge', 'dumbbells', 'kg', 'strength', 'Square hips, slight knee bend. Reach long — balance comes from the glute.', true),
('Stiff-Leg Deadlift', 'SLDL', 'hamstrings', 'hinge', 'barbell', 'kg', 'strength', 'Straighter knees than an RDL. Stop where your back wants to round.', true),
('Good Morning', null, 'hamstrings', 'hinge', 'barbell', 'kg', 'strength', 'Bar on the back, bow forward from the hips. Light weight, big stretch.', true),
('Lying Leg Curl', null, 'hamstrings', 'hinge', 'machine', 'kg', 'pump', 'Hips pressed down. Curl slow, lower slower.', true),
('Seated Leg Curl', null, 'hamstrings', 'hinge', 'machine', 'kg', 'pump', 'Chest tall against the pad. Full stretch at the top of every rep.', true),
-- hinge · glutes
('Cable Pull-Through', null, 'glutes', 'hinge', 'cable', 'kg', 'pump', 'Face away, rope between legs. Hinge back, then snap hips through and squeeze.', true),
('Back Extension', 'GLUTE EXT', 'glutes', 'hinge', 'bodyweight', 'kg', 'pump', 'Round the upper back slightly, tuck chin. Lift with glutes, not lower back.', true),
('Kettlebell Swing', null, 'glutes', 'hinge', 'kettlebell', 'kg', 'pump', 'It is a hinge, not a squat. Hips do the throwing, arms just steer.', true),
('Sumo Deadlift', null, 'glutes', 'hinge', 'barbell', 'kg', 'strength', 'Wide stance, toes out, chest proud. Push the floor away.', true),
('Conventional Deadlift', null, 'glutes', 'hinge', 'barbell', 'kg', 'strength', 'Bar over mid-foot, brace hard. Stand up tall — no jerking off the floor.', true),
-- thrust · glutes
('Hip Thrust', null, 'glutes', 'thrust', 'barbell', 'kg', 'strength', 'Chin tucked, ribs down. Drive through heels to full lockout, one-second squeeze.', true),
('Hip Thrust Machine', null, 'glutes', 'thrust', 'machine', 'kg', 'strength', 'Same rules as the barbell: full lockout, posterior tilt, squeeze at the top.', true),
('Smith Machine Hip Thrust', null, 'glutes', 'thrust', 'smith machine', 'kg', 'strength', 'Fixed bar path lets you focus on the squeeze. Pause every rep at the top.', true),
('Barbell Glute Bridge', null, 'glutes', 'thrust', 'barbell', 'kg', 'strength', 'From the floor. Shorter range than a thrust — load it heavier, squeeze harder.', true),
('Dumbbell Glute Bridge', null, 'glutes', 'thrust', 'dumbbell', 'kg', 'pump', 'Dumbbell on hips, heels close. Drive up, hold one second.', true),
('Single-Leg Hip Thrust', null, 'glutes', 'thrust', 'bodyweight', 'kg', 'pump', 'Hips stay level — do not let the free side drop. Slow negatives.', true),
('Frog Pumps', null, 'glutes', 'thrust', 'dumbbell', 'kg', 'pump', 'Soles of feet together, knees wide. Short fast pumps, constant tension.', true),
('Cable Kickbacks', null, 'glutes', 'thrust', 'cable', 'kg', 'pump', 'Slight forward lean, kick back and up. The glute moves the leg — no swinging.', true),
('Cable Donkey Kicks', null, 'glutes', 'thrust', 'cable', 'kg', 'pump', 'On all fours or standing bent over. Drive the heel to the ceiling, pause.', true),
('Machine Kickback', null, 'glutes', 'thrust', 'machine', 'kg', 'pump', 'Push through the heel, full hip extension, control the return.', true),
('Glute Bridge Hold', null, 'glutes', 'thrust', 'bodyweight', 's', 'timed', 'Finisher: hold the top of a bridge and squeeze like you mean it. Log seconds.', true),
-- lunge · glutes
('Bulgarian Split Squat', 'BSS', 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Long stance, torso leaning slightly forward. The front heel does all the work.', true),
('Walking Lunges', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Long steps, knee kisses the floor. Push through the front heel to travel.', true),
('Reverse Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Step back, drop straight down. Easier on knees, heavier on glutes.', true),
('Curtsy Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Step behind and across. Stay tall — feel the side of the glute.', true),
('Step-Ups', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Bench height, whole foot on the box. Push through the heel — no bouncing.', true),
('Forward Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Controlled step out, push back through the heel to return.', true),
('Smith Machine Split Squat', null, 'glutes', 'lunge', 'smith machine', 'kg', 'strength', 'Front foot far forward, sink straight down. Let the machine balance for you.', true),
('Deficit Reverse Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Stand on a small plate or step. The extra depth is the point — go slow.', true),
-- squat · glutes
('Back Squat', null, 'glutes', 'squat', 'barbell', 'kg', 'strength', 'Brace, sit between your hips. Depth over load — hips below parallel.', true),
('Goblet Squat', null, 'glutes', 'squat', 'dumbbell', 'kg', 'strength', 'Dumbbell at chest, elbows inside knees at the bottom. Stay upright.', true),
('Smith Machine Squat', null, 'glutes', 'squat', 'smith machine', 'kg', 'strength', 'Feet slightly forward of the bar. Sit back into it — glutes take over.', true),
('Hack Squat', null, 'glutes', 'squat', 'machine', 'kg', 'strength', 'Back flat on the pad, full depth. Drive evenly through the whole foot.', true),
('Leg Press', 'GLUTE PRESS', 'glutes', 'squat', 'machine', 'kg', 'strength', 'Feet high and wide on the platform for glute bias. Deep, controlled reps.', true),
('Sumo Squat', null, 'glutes', 'squat', 'dumbbell', 'kg', 'strength', 'Wide stance, toes out, dumbbell hanging heavy. Sink straight down.', true),
('Box Squat', null, 'glutes', 'squat', 'barbell', 'kg', 'strength', 'Sit back to the box, pause a beat, drive up. No rocking.', true),
('Pendulum Squat', null, 'glutes', 'squat', 'machine', 'kg', 'strength', 'Smooth arc, huge range. Stay deep and controlled.', true),
-- abduction · glutes
('Seated Hip Abduction Machine', null, 'glutes', 'abduction', 'machine', 'kg', 'pump', 'Press knees out to the sides, pause at the widest point. Lean forward for more glute.', true),
('Standing Cable Hip Abduction', null, 'glutes', 'abduction', 'cable', 'kg', 'pump', 'Cuff at the ankle, lift the leg straight out to the side. Stay tall.', true),
('Banded Lateral Walks', null, 'glutes', 'abduction', 'band', 'kg', 'pump', 'Band above knees, quarter-squat stance. Small lateral steps, constant tension.', true),
('Side-Lying Hip Abduction', null, 'glutes', 'abduction', 'bodyweight', 'kg', 'pump', 'Top leg slightly behind you, toes down. Lift with the side of the glute.', true),
('Banded Clamshells', null, 'glutes', 'abduction', 'band', 'kg', 'pump', 'Heels together, open the top knee against the band. Slow and strict.', true),
-- pull · back
('Lat Pulldown', null, 'back', 'pull', 'cable', 'kg', 'strength', 'Pull the bar to the collarbone, elbows down and in. Chest stays proud.', true),
('Close-Grip Lat Pulldown', null, 'back', 'pull', 'cable', 'kg', 'strength', 'Neutral close grip. Pull elbows to your ribs, stretch fully at the top.', true),
('Assisted Pull-Up', null, 'back', 'pull', 'machine', 'kg', 'strength', 'Full hang at the bottom, chin over bar at the top. Log the assist weight.', true),
('Seated Cable Row', null, 'back', 'pull', 'cable', 'kg', 'strength', 'Tall posture, pull the handle to your navel. Squeeze shoulder blades together.', true),
('Single-Arm Dumbbell Row', null, 'back', 'pull', 'dumbbell', 'kg', 'strength', 'Hand on bench, flat back. Pull the elbow to your hip, not your shoulder.', true),
('Chest-Supported Row', null, 'back', 'pull', 'dumbbells', 'kg', 'strength', 'Chest glued to the incline pad. No cheating — just lats and rhomboids.', true),
('Machine Row', null, 'back', 'pull', 'machine', 'kg', 'strength', 'Drive elbows back, pause, control the stretch forward.', true),
('Straight-Arm Pulldown', null, 'back', 'pull', 'cable', 'kg', 'pump', 'Arms long, sweep the bar to your thighs. Feel the lats the whole way.', true),
-- pull · arms
('Bicep Curls', null, 'arms', 'pull', 'dumbbells', 'kg', 'pump', 'Elbows pinned at your sides. Curl up, lower for three seconds.', true),
('Hammer Curls', null, 'arms', 'pull', 'dumbbells', 'kg', 'pump', 'Neutral grip, no swinging. Slim strong arms are built slow.', true),
('Cable Curls', null, 'arms', 'pull', 'cable', 'kg', 'pump', 'Constant tension top to bottom. Stand a step back from the stack.', true),
('EZ-Bar Curls', null, 'arms', 'pull', 'barbell', 'kg', 'pump', 'Comfortable angled grip. Squeeze at the top, full stretch at the bottom.', true),
-- push · shoulders
('Dumbbell Shoulder Press', null, 'shoulders', 'push', 'dumbbells', 'kg', 'strength', 'Light and strict. Press to lockout without flaring the ribs.', true),
('Machine Shoulder Press', null, 'shoulders', 'push', 'machine', 'kg', 'strength', 'Settle into the seat, press smooth. No lockout slamming.', true),
('Arnold Press', null, 'shoulders', 'push', 'dumbbells', 'kg', 'strength', 'Rotate palms as you press. Light weight, full rotation.', true),
('Lateral Raises', null, 'shoulders', 'push', 'dumbbells', 'kg', 'pump', 'Lead with the elbows, stop at shoulder height. Lighter than you think.', true),
('Cable Lateral Raises', null, 'shoulders', 'push', 'cable', 'kg', 'pump', 'Cable behind the body. Constant tension — strict, floaty reps.', true),
('Machine Lateral Raise', null, 'shoulders', 'push', 'machine', 'kg', 'pump', 'Pads at the elbows, raise to parallel. Pause briefly at the top.', true),
-- push · chest
('Dumbbell Bench Press', null, 'chest', 'push', 'dumbbells', 'kg', 'strength', 'Shoulder blades pinned back, feet planted. Lower with control, press up and slightly in.', true),
('Push-Up', null, 'chest', 'push', 'bodyweight', 'kg', 'strength', 'One straight line head to heels. Chest to the floor, elbows ~45°. Knees down is still a push-up.', true),
('Machine Chest Press', null, 'chest', 'push', 'machine', 'kg', 'strength', 'Handles at mid-chest height. Press smooth, stretch wide on the return.', true),
('Incline Dumbbell Press', null, 'chest', 'push', 'dumbbells', 'kg', 'strength', 'Low incline. Press up and together, lower to a deep comfortable stretch.', true),
-- push · arms (triceps)
('Triceps Rope Pushdown', null, 'arms', 'push', 'cable', 'kg', 'pump', 'Elbows pinned, split the rope at the bottom. Full extension every rep.', true),
('Overhead Cable Triceps Extension', null, 'arms', 'push', 'cable', 'kg', 'pump', 'Face away, arms overhead. Big stretch behind the head, press to lockout.', true),
('Skullcrushers', null, 'arms', 'push', 'barbell', 'kg', 'pump', 'Lower to the forehead, elbows still. Light bar, perfect reps.', true),
('Bench Dips', null, 'arms', 'push', 'bodyweight', 'kg', 'pump', 'Hands on the bench behind you, hips close. Elbows point straight back.', true),
-- core
('Cable Crunch', null, 'core', 'core', 'cable', 'kg', 'pump', 'Kneel, rope at your ears. Crunch ribs to hips — the hips do not move.', true),
('Pallof Press', null, 'core', 'core', 'cable', 'kg', 'pump', 'Press the handle straight out and resist the twist. Breathe.', true),
('Plank with Reach', null, 'core', 'core', 'bodyweight', 's', 'timed', 'From a plank, reach one arm forward without the hips tipping. Log seconds.', true),
('Dead Bug', null, 'core', 'core', 'bodyweight', 'kg', 'pump', 'Lower back pressed into the floor. Opposite arm and leg, slow.', true),
('Hanging Knee Raise', null, 'core', 'core', 'bodyweight', 'kg', 'pump', 'Knees to chest with a posterior tilt at the top. No swinging.', true),
('Ab Wheel Rollout', null, 'core', 'core', 'wheel', 'kg', 'pump', 'Roll out only as far as the lower back stays flat. Earn the range.', true),
('Side Plank', null, 'core', 'core', 'bodyweight', 's', 'timed', 'Straight line ear to ankle. Lift the hip away from the floor. Log seconds.', true),
('Hollow Hold', null, 'core', 'core', 'bodyweight', 's', 'timed', 'Lower back pressed down, arms and legs long. Log seconds.', true),
('Weighted Decline Sit-Up', null, 'core', 'core', 'dumbbell', 'kg', 'pump', 'Plate at the chest. Curl up one vertebra at a time.', true),
-- accessory · calves
('Calf Raises', null, 'calves', 'accessory', 'machine', 'kg', 'pump', 'Pause at the deep stretch, drive to your tiptoes. Full range, no bouncing.', true),
('Seated Calf Raise', null, 'calves', 'accessory', 'machine', 'kg', 'pump', 'Slow stretch at the bottom — that is where calves grow.', true),
('Smith Machine Calf Raise', null, 'calves', 'accessory', 'smith machine', 'kg', 'pump', 'Balls of feet on a plate, full stretch, full squeeze.', true),
('Leg Press Calf Raise', null, 'calves', 'accessory', 'machine', 'kg', 'pump', 'Press with the balls of your feet only. Knees stay softly locked.', true)
on conflict (name) where is_global do nothing;

-- --------------------------------------------- "Lean & Sculpted" template
-- Global program template (user_id null). Cloned per user at onboarding.
with prog as (
  insert into public.programs (user_id, name, weeks, days_per_week, active)
  values (null, 'Lean & Sculpted', 3, 5, true)
  returning id
),
days as (
  insert into public.program_days (program_id, day_index, name)
  select prog.id, d.idx, d.name
  from prog, (values
    (1, 'Glutes & Hamstrings'),
    (2, 'Upper Body Lean'),
    (3, 'Glutes & Quads'),
    (4, 'Core & Back'),
    (5, 'Booty Volume')
  ) as d(idx, name)
  returning id, day_index
)
insert into public.program_exercises (program_day_id, exercise_id, sort, sets)
select days.id, e.id, x.sort, 3
from days
join (values
  -- Day 1 — Glutes & Hamstrings (hinge focus)
  (1, 1, 'Romanian Deadlift'),
  (1, 2, 'Hip Thrust'),
  (1, 3, 'Bulgarian Split Squat'),
  (1, 4, 'Cable Donkey Kicks'),
  (1, 5, 'Seated Hip Abduction Machine'),
  (1, 6, 'Lying Leg Curl'),
  -- Day 2 — Upper Body Lean (pull + push)
  (2, 1, 'Lat Pulldown'),
  (2, 2, 'Dumbbell Bench Press'),
  (2, 3, 'Dumbbell Shoulder Press'),
  (2, 4, 'Lateral Raises'),
  (2, 5, 'Triceps Rope Pushdown'),
  (2, 6, 'Bicep Curls'),
  -- Day 3 — Glutes & Quads (squat focus)
  (3, 1, 'Back Squat'),
  (3, 2, 'Walking Lunges'),
  (3, 3, 'Leg Press'),
  (3, 4, 'Hip Thrust Machine'),
  (3, 5, 'Standing Cable Hip Abduction'),
  (3, 6, 'Calf Raises'),
  -- Day 4 — Core & Back
  (4, 1, 'Close-Grip Lat Pulldown'),
  (4, 2, 'Single-Arm Dumbbell Row'),
  (4, 3, 'Back Extension'),
  (4, 4, 'Cable Crunch'),
  (4, 5, 'Pallof Press'),
  (4, 6, 'Plank with Reach'),
  -- Day 5 — Booty Volume (pump day) — compounds first, pumps last
  (5, 1, 'Sumo Squat'),
  (5, 2, 'Step-Ups'),
  (5, 3, 'Cable Kickbacks'),
  (5, 4, 'Frog Pumps'),
  (5, 5, 'Banded Lateral Walks'),
  (5, 6, 'Glute Bridge Hold')
) as x(day_idx, sort, exercise_name) on x.day_idx = days.day_index
join public.exercises e on e.name = x.exercise_name and e.is_global;

-- ------------------------------------------------------------------ quotes
insert into public.quotes (text, author) values
('Strong is quiet.', null),
('Show up. That''s the whole secret.', null),
('You don''t have to feel ready. You have to begin.', null),
('Consistency looks boring up close and stunning from a distance.', null),
('The body keeps every promise you keep to it.', null),
('Lift like nobody''s watching, because nobody is.', null),
('Slow progress is still progress. Fast quitting is still quitting.', null),
('Your only competition is yesterday''s session.', null),
('Discipline is choosing what you want most over what you want now.', null),
('You are building something nobody can take from you.', null),
('Rest is part of the work.', null),
('A calm mind lifts heavier than an anxious one.', null),
('Three sets. Then decide who you are.', null),
('Strength is a practice, not a destination.', null),
('Small weights, long years, remarkable body.', null),
('It never gets easier. You get stronger.', null),
('The hardest rep is leaving the house.', null),
('Today''s light week is next month''s warm-up.', null),
('Grace and grit live in the same body.', null),
('You can''t rush a sculpture.', null),
('Quiet effort, loud results.', null),
('The gym doesn''t care how you feel. Go anyway, gently.', null),
('Every session is a vote for the person you''re becoming.', null),
('Muscles are built in the reps you don''t post.', null),
('Be patient with your body. It''s working for you.', null),
('Strong glutes, calm mind, soft heart.', null),
('What you do four times a week becomes who you are.', null),
('Sweat now, glow always.', null),
('Heavy things, lifted lightly, over and over.', null),
('Your future self is spotting you.', null),
('Progress hides in the weeks that feel like nothing.', null),
('Don''t count the days. Make the days count.', null),
('A good session is one you showed up for.', null),
('Trust the cycle. Light, medium, hard, repeat.', null),
('You''ve done hard things before breakfast.', null),
('Strength suits you.', null),
('One more rep is a love letter to yourself.', null),
('The bar doesn''t know it''s Monday.', null),
('Train like you''ll live in this body forever. You will.', null),
('Soft days build strong years.', null);
