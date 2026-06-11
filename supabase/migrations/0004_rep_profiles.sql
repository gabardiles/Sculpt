-- Sculpt — rep profiles + program fixes from the training audit.
--
-- One global rep wave (10–12 / 6–8 / 4–6) made hard week prescribe 4-rep
-- lateral raises and 6-second planks. Each exercise now carries a training
-- role: 'strength' keeps the original wave, 'pump' waves 15–20 / 12–15 /
-- 10–12, 'timed' waves hold seconds. The role also tiers swap suggestions.
-- Also: adds a horizontal press (library gap), swaps one Day-1 hinge for a
-- knee-flexion hamstring movement, and moves Frog Pumps out of slot 2.
-- Program updates match by day name, so they apply to the template AND
-- programs already cloned by users.

alter table public.exercises
  add column if not exists rep_profile text not null default 'strength'
  check (rep_profile in ('strength','pump','timed'));

-- Global exercise names are unique from here on — lets seed.sql re-run
-- safely alongside this migration's inserts.
create unique index if not exists exercises_global_name
  on public.exercises (name) where is_global;

update public.exercises set rep_profile = 'timed' where unit = 's';

update public.exercises set rep_profile = 'pump' where unit = 'kg' and name in (
  'Cable Pull-Through', 'Back Extension', 'Kettlebell Swing',
  'Lying Leg Curl', 'Seated Leg Curl',
  'Single-Leg Hip Thrust', 'Frog Pumps', 'Cable Kickbacks',
  'Cable Donkey Kicks', 'Machine Kickback', 'Dumbbell Glute Bridge',
  'Seated Hip Abduction Machine', 'Standing Cable Hip Abduction',
  'Banded Lateral Walks', 'Side-Lying Hip Abduction', 'Banded Clamshells',
  'Straight-Arm Pulldown',
  'Bicep Curls', 'Hammer Curls', 'Cable Curls', 'EZ-Bar Curls',
  'Lateral Raises', 'Cable Lateral Raises', 'Machine Lateral Raise',
  'Triceps Rope Pushdown', 'Overhead Cable Triceps Extension',
  'Skullcrushers', 'Bench Dips',
  'Cable Crunch', 'Pallof Press', 'Dead Bug', 'Hanging Knee Raise',
  'Ab Wheel Rollout', 'Weighted Decline Sit-Up',
  'Calf Raises', 'Seated Calf Raise', 'Smith Machine Calf Raise',
  'Leg Press Calf Raise'
);

-- Horizontal pressing was missing from the library entirely.
insert into public.exercises (name, short_label, muscle_group, movement_pattern, equipment, unit, rep_profile, cue, is_global) values
('Dumbbell Bench Press', null, 'chest', 'push', 'dumbbells', 'kg', 'strength', 'Shoulder blades pinned back, feet planted. Lower with control, press up and slightly in.', true),
('Push-Up', null, 'chest', 'push', 'bodyweight', 'kg', 'strength', 'One straight line head to heels. Chest to the floor, elbows ~45°. Knees down is still a push-up.', true),
('Machine Chest Press', null, 'chest', 'push', 'machine', 'kg', 'strength', 'Handles at mid-chest height. Press smooth, stretch wide on the return.', true),
('Incline Dumbbell Press', null, 'chest', 'push', 'dumbbells', 'kg', 'strength', 'Low incline. Press up and together, lower to a deep comfortable stretch.', true)
on conflict (name) where is_global do nothing;

-- Day 1: third hinge of the day → direct knee-flexion hamstring work.
update public.program_exercises pe
set exercise_id = (select id from public.exercises where name = 'Lying Leg Curl' and is_global limit 1)
where pe.exercise_id = (select id from public.exercises where name = 'Cable Pull-Through' and is_global limit 1)
  and exists (
    select 1 from public.program_days d
    where d.id = pe.program_day_id and d.name = 'Glutes & Hamstrings');

-- Day 2: second pull → the program's one horizontal press.
update public.program_exercises pe
set exercise_id = (select id from public.exercises where name = 'Dumbbell Bench Press' and is_global limit 1)
where pe.exercise_id = (select id from public.exercises where name = 'Seated Cable Row' and is_global limit 1)
  and exists (
    select 1 from public.program_days d
    where d.id = pe.program_day_id and d.name = 'Upper Body Lean');

-- Day 5: compounds first, pump work last (Frog Pumps was slot 2).
update public.program_exercises pe
set sort = x.sort
from (values
  ('Sumo Squat', 1),
  ('Step-Ups', 2),
  ('Cable Kickbacks', 3),
  ('Frog Pumps', 4),
  ('Banded Lateral Walks', 5),
  ('Glute Bridge Hold', 6)
) as x(name, sort)
join public.exercises e on e.name = x.name and e.is_global
join public.program_days d on d.name = 'Booty Volume'
where pe.exercise_id = e.id and pe.program_day_id = d.id;
