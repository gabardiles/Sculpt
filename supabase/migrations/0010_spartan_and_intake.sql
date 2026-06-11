-- Sculpt — Spartan edition + cycle intake.
-- New columns, 13 new library exercises, the "Strong & Built" men's
-- template (coach-designed, docs/spartan-program.md), spartan quotes.

-- ----------------------------------------------------------------- columns
alter table public.profiles
  add column if not exists theme text not null default 'sculpt'
  check (theme in ('sculpt','spartan'));

-- Intake answers (jsonb: {glutes, strong, lean, applied_cycle, applied_at})
alter table public.programs add column if not exists intake jsonb;

-- ----------------------------------------------------- new exercises (13)
insert into public.exercises (name, short_label, muscle_group, movement_pattern, equipment, unit, rep_profile, cue, is_global) values
('Barbell Bench Press', null, 'chest', 'push', 'barbell', 'kg', 'strength', 'Shoulder blades pinned, feet planted. Lower to the chest with control, press back over the shoulders.', true),
('Overhead Press', 'OHP', 'shoulders', 'push', 'barbell', 'kg', 'strength', 'Glutes tight, ribs down. Press to lockout and bring your head through at the top.', true),
('Weighted Dip', null, 'chest', 'push', 'dip station', 'kg', 'strength', 'Slight forward lean, elbows tracking back, deep stretch. Earn strict bodyweight reps before adding plates.', true),
('Weighted Pull-Up', null, 'back', 'pull', 'pull-up bar', 'kg', 'strength', 'Full hang, then drive the elbows down to your ribs. Chin over the bar, no kicking.', true),
('Barbell Row', null, 'back', 'pull', 'barbell', 'kg', 'strength', 'Hinge to forty-five degrees and brace like a deadlift. Pull to the lower ribs — the lats do the work.', true),
('Close-Grip Bench Press', 'CGBP', 'arms', 'push', 'barbell', 'kg', 'strength', 'Hands just inside shoulder width, elbows tucked. Touch low on the chest, press with the triceps.', true),
('Face Pull', null, 'shoulders', 'pull', 'cable', 'kg', 'pump', 'Rope to the bridge of the nose, elbows high and wide. Finish like a double-biceps pose, pause a beat.', true),
('Dumbbell Rear Delt Fly', null, 'shoulders', 'pull', 'dumbbells', 'kg', 'pump', 'Hinge over, soft elbows. Sweep wide and lead with the pinkies — no momentum.', true),
('Reverse Pec Deck', null, 'shoulders', 'pull', 'machine', 'kg', 'pump', 'Arms long, sweep back until the hands pass the shoulders. Pause where it burns.', true),
('Band Pull-Apart', null, 'shoulders', 'pull', 'band', 'kg', 'pump', 'Arms straight, pull the band to your chest. Squeeze the blades together, control the return.', true),
('Dumbbell Front Raise', null, 'shoulders', 'push', 'dumbbells', 'kg', 'pump', 'Raise to eye level, no lean-back. Lighter than pride suggests.', true),
('Cable Fly', null, 'chest', 'push', 'cable', 'kg', 'pump', 'Slight elbow bend, like hugging a barrel. Deep stretch, then squeeze the hands together.', true),
('Machine Chest Fly', null, 'chest', 'push', 'machine', 'kg', 'pump', 'Open wide into the stretch — that''s where chests grow. Squeeze the handles together and pause.', true)
on conflict (name) where is_global do nothing;

-- -------------------------------------- "Strong & Built" template (once)
with prog as (
  insert into public.programs (user_id, name, weeks, days_per_week, active)
  select null, 'Strong & Built', 3, 5, true
  where not exists (
    select 1 from public.programs where user_id is null and name = 'Strong & Built')
  returning id
),
days as (
  insert into public.program_days (program_id, day_index, name)
  select prog.id, d.idx, d.name
  from prog, (values
    (1, 'Push'),
    (2, 'Pull'),
    (3, 'Legs'),
    (4, 'Shoulders & Arms'),
    (5, 'Chest, Back & Core')
  ) as d(idx, name)
  returning id, day_index
)
insert into public.program_exercises (program_day_id, exercise_id, sort, sets)
select days.id, e.id, x.sort, 3
from days
join (values
  (1, 1, 'Barbell Bench Press'),
  (1, 2, 'Overhead Press'),
  (1, 3, 'Weighted Dip'),
  (1, 4, 'Lateral Raises'),
  (1, 5, 'Triceps Rope Pushdown'),
  (1, 6, 'Overhead Cable Triceps Extension'),
  (2, 1, 'Weighted Pull-Up'),
  (2, 2, 'Barbell Row'),
  (2, 3, 'Seated Cable Row'),
  (2, 4, 'Face Pull'),
  (2, 5, 'EZ-Bar Curls'),
  (2, 6, 'Hammer Curls'),
  (3, 1, 'Back Squat'),
  (3, 2, 'Romanian Deadlift'),
  (3, 3, 'Bulgarian Split Squat'),
  (3, 4, 'Lying Leg Curl'),
  (3, 5, 'Calf Raises'),
  (3, 6, 'Hanging Knee Raise'),
  (4, 1, 'Dumbbell Shoulder Press'),
  (4, 2, 'Close-Grip Bench Press'),
  (4, 3, 'Cable Lateral Raises'),
  (4, 4, 'Dumbbell Rear Delt Fly'),
  (4, 5, 'Cable Curls'),
  (4, 6, 'Skullcrushers'),
  (5, 1, 'Incline Dumbbell Press'),
  (5, 2, 'Lat Pulldown'),
  (5, 3, 'Chest-Supported Row'),
  (5, 4, 'Straight-Arm Pulldown'),
  (5, 5, 'Ab Wheel Rollout'),
  (5, 6, 'Hollow Hold')
) as x(day_idx, sort, exercise_name) on x.day_idx = days.day_index
join public.exercises e on e.name = x.exercise_name and e.is_global;

-- ------------------------------------------------- spartan quotes (once)
insert into public.quotes (text, author)
select v.q, v.a from (values
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
  ('Spartans do not ask how many the enemy are, only where they are.', 'Agis II')
) as v(q, a)
where not exists (select 1 from public.quotes where text = v.q);
