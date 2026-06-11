-- ============================================================================
-- Sculpt — one-shot idempotent setup
--
-- Replaces running 0001/0002/0004/seed/0003 by hand. Safe to run on a fresh
-- database, a partially migrated one, or one where things were run twice —
-- every statement either guards itself or is a no-op on re-run.
--
-- Run this WHOLE file in the Supabase SQL editor, then run
-- storage_policies.sql as a separate query (see note in that file).
-- ============================================================================

-- ------------------------------------------------------------ core schema
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text,
  is_admin boolean not null default false,
  invited_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists friend_code text not null unique
  default upper(substring(md5(gen_random_uuid()::text), 1, 6));

alter table public.profiles
  add column if not exists theme text not null default 'sculpt'
  check (theme in ('sculpt','spartan'));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for users created before the trigger existed.
insert into public.profiles (id)
select u.id from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_label text,
  muscle_group text not null,
  movement_pattern text not null check (movement_pattern in
    ('hinge','squat','lunge','thrust','abduction','push','pull','core','accessory')),
  equipment text,
  instruction_url text,
  cue text,
  image_url text,
  unit text not null default 'kg' check (unit in ('kg','s')),
  rep_profile text not null default 'strength'
    check (rep_profile in ('strength','pump','timed')),
  is_global boolean not null default false,
  created_by uuid references auth.users (id)
);

alter table public.exercises
  add column if not exists rep_profile text not null default 'strength'
  check (rep_profile in ('strength','pump','timed'));

create table if not exists public.programs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade,
  name text not null,
  weeks int not null default 3,
  days_per_week int not null default 5,
  active boolean not null default true,
  cycle_floor int not null default 1,
  created_at timestamptz not null default now()
);

alter table public.programs add column if not exists intake jsonb;

create table if not exists public.program_days (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete cascade,
  day_index int not null,
  name text not null
);

create table if not exists public.program_exercises (
  id uuid primary key default gen_random_uuid(),
  program_day_id uuid not null references public.program_days (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  sort int not null default 0,
  sets int not null default 3
);

create table if not exists public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  program_day_id uuid not null references public.program_days (id),
  week_phase text not null check (week_phase in ('light','medium','hard')),
  cycle_number int not null default 1,
  completed_at timestamptz not null default now(),
  feel_rating int check (feel_rating between 1 and 5)
);

create table if not exists public.set_logs (
  id uuid primary key default gen_random_uuid(),
  workout_log_id uuid not null references public.workout_logs (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  weight_kg numeric,
  reps int,
  sets int
);

alter table public.set_logs add column if not exists sets int;

create table if not exists public.body_weight (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null default current_date,
  weight_kg numeric not null,
  unique (user_id, date)
);

create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  cycle_number int not null default 1,
  week_label text not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('body_weight','exercise_pr','consistency')),
  target_value numeric not null,
  baseline_value numeric,
  exercise_id uuid references public.exercises (id),
  deadline date,
  achieved boolean not null default false,
  achieved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  author text
);

create table if not exists public.friends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  friend_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, friend_id),
  check (user_id <> friend_id)
);

create table if not exists public.feed_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('workout','pb','photo','message')),
  body text,
  storage_path text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.feed_cheers (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

-- A week counts as complete at 3 of 5 sessions; closing early is explicit.
create table if not exists public.week_closures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  cycle_number int not null,
  week_phase text not null check (week_phase in ('light','medium','hard')),
  created_at timestamptz not null default now(),
  unique (user_id, cycle_number, week_phase)
);

-- --------------------------------------------------------------- functions
create or replace function public.add_friend(code text)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  target uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'Not signed in.');
  end if;
  select id into target from public.profiles
    where friend_code = upper(trim(code));
  if target is null then
    return jsonb_build_object('ok', false, 'error', 'No one has that code.');
  end if;
  if target = auth.uid() then
    return jsonb_build_object('ok', false, 'error', 'That''s your own code.');
  end if;
  insert into public.friends (user_id, friend_id)
    values (auth.uid(), target), (target, auth.uid())
    on conflict do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.add_friend(text) from public;
grant execute on function public.add_friend(text) to authenticated;

-- --------------------------------------------------------------------- RLS
alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.programs enable row level security;
alter table public.program_days enable row level security;
alter table public.program_exercises enable row level security;
alter table public.workout_logs enable row level security;
alter table public.set_logs enable row level security;
alter table public.body_weight enable row level security;
alter table public.progress_photos enable row level security;
alter table public.goals enable row level security;
alter table public.quotes enable row level security;
alter table public.friends enable row level security;
alter table public.feed_posts enable row level security;
alter table public.feed_cheers enable row level security;
alter table public.week_closures enable row level security;

drop policy if exists "week_closures own" on public.week_closures;
create policy "week_closures own" on public.week_closures
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "profiles own read" on public.profiles;
create policy "profiles own read" on public.profiles
  for select using (auth.uid() = id);
drop policy if exists "profiles own update" on public.profiles;
create policy "profiles own update" on public.profiles
  for update using (auth.uid() = id);
-- Column-level guard: only `name` is user-editable (is_admin etc. are not).
revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;
grant update (name) on public.profiles to authenticated;
drop policy if exists "profiles friends read" on public.profiles;
create policy "profiles friends read" on public.profiles
  for select using (
    exists (
      select 1 from public.friends f
      where f.user_id = auth.uid() and f.friend_id = profiles.id
    )
  );

drop policy if exists "exercises read" on public.exercises;
create policy "exercises read" on public.exercises
  for select using (is_global or created_by = auth.uid());
drop policy if exists "exercises insert own" on public.exercises;
create policy "exercises insert own" on public.exercises
  for insert with check (created_by = auth.uid());

drop policy if exists "programs read" on public.programs;
create policy "programs read" on public.programs
  for select using (user_id = auth.uid() or user_id is null);
drop policy if exists "programs insert own" on public.programs;
create policy "programs insert own" on public.programs
  for insert with check (user_id = auth.uid());
drop policy if exists "programs update own" on public.programs;
create policy "programs update own" on public.programs
  for update using (user_id = auth.uid());

drop policy if exists "program_days read" on public.program_days;
create policy "program_days read" on public.program_days
  for select using (exists (
    select 1 from public.programs p
    where p.id = program_id and (p.user_id = auth.uid() or p.user_id is null)));
drop policy if exists "program_days write" on public.program_days;
create policy "program_days write" on public.program_days
  for all using (exists (
    select 1 from public.programs p
    where p.id = program_id and p.user_id = auth.uid()))
  with check (exists (
    select 1 from public.programs p
    where p.id = program_id and p.user_id = auth.uid()));

drop policy if exists "program_exercises read" on public.program_exercises;
create policy "program_exercises read" on public.program_exercises
  for select using (exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_id and (p.user_id = auth.uid() or p.user_id is null)));
drop policy if exists "program_exercises write" on public.program_exercises;
create policy "program_exercises write" on public.program_exercises
  for all using (exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_id and p.user_id = auth.uid()))
  with check (exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_id and p.user_id = auth.uid()));

drop policy if exists "workout_logs own" on public.workout_logs;
create policy "workout_logs own" on public.workout_logs
  for all using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.program_days d
      join public.programs p on p.id = d.program_id
      where d.id = program_day_id and p.user_id = auth.uid()
    )
  );
drop policy if exists "set_logs own" on public.set_logs;
create policy "set_logs own" on public.set_logs
  for all using (exists (
    select 1 from public.workout_logs w
    where w.id = workout_log_id and w.user_id = auth.uid()))
  with check (exists (
    select 1 from public.workout_logs w
    where w.id = workout_log_id and w.user_id = auth.uid()));
drop policy if exists "body_weight own" on public.body_weight;
create policy "body_weight own" on public.body_weight
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "progress_photos own" on public.progress_photos;
create policy "progress_photos own" on public.progress_photos
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "goals own" on public.goals;
create policy "goals own" on public.goals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "quotes read" on public.quotes;
create policy "quotes read" on public.quotes for select using (true);

drop policy if exists "friends read own" on public.friends;
create policy "friends read own" on public.friends
  for select using (user_id = auth.uid() or friend_id = auth.uid());
drop policy if exists "friends delete own" on public.friends;
create policy "friends delete own" on public.friends
  for delete using (user_id = auth.uid() or friend_id = auth.uid());

drop policy if exists "feed read self or friends" on public.feed_posts;
create policy "feed read self or friends" on public.feed_posts
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.friends f
      where f.user_id = auth.uid() and f.friend_id = feed_posts.user_id
    )
  );
drop policy if exists "feed insert own" on public.feed_posts;
create policy "feed insert own" on public.feed_posts
  for insert with check (user_id = auth.uid());
drop policy if exists "feed delete own" on public.feed_posts;
create policy "feed delete own" on public.feed_posts
  for delete using (user_id = auth.uid());

-- Cheers are only visible/insertable where the underlying post is visible.
drop policy if exists "cheers read visible posts" on public.feed_cheers;
create policy "cheers read visible posts" on public.feed_cheers
  for select using (
    exists (
      select 1 from public.feed_posts p
      where p.id = post_id
        and (
          p.user_id = auth.uid()
          or exists (
            select 1 from public.friends f
            where f.user_id = auth.uid() and f.friend_id = p.user_id
          )
        )
    )
  );
drop policy if exists "cheers insert own" on public.feed_cheers;
create policy "cheers insert own" on public.feed_cheers
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.feed_posts p
      where p.id = post_id
        and (
          p.user_id = auth.uid()
          or exists (
            select 1 from public.friends f
            where f.user_id = auth.uid() and f.friend_id = p.user_id
          )
        )
    )
  );
drop policy if exists "cheers delete own" on public.feed_cheers;
create policy "cheers delete own" on public.feed_cheers
  for delete using (user_id = auth.uid());

-- Comments: visible/insertable only where the post is visible to the caller.
alter table public.feed_comments enable row level security;
drop policy if exists "comments read visible posts" on public.feed_comments;
create policy "comments read visible posts" on public.feed_comments
  for select using (
    exists (
      select 1 from public.feed_posts p
      where p.id = post_id
        and (
          p.user_id = auth.uid()
          or exists (
            select 1 from public.friends f
            where f.user_id = auth.uid() and f.friend_id = p.user_id
          )
        )
    )
  );
drop policy if exists "comments insert own" on public.feed_comments;
create policy "comments insert own" on public.feed_comments
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.feed_posts p
      where p.id = post_id
        and (
          p.user_id = auth.uid()
          or exists (
            select 1 from public.friends f
            where f.user_id = auth.uid() and f.friend_id = p.user_id
          )
        )
    )
  );
drop policy if exists "comments delete own" on public.feed_comments;
create policy "comments delete own" on public.feed_comments
  for delete using (user_id = auth.uid());

-- ----------------------------------------------------------------- indexes
create index if not exists feed_comments_post on public.feed_comments (post_id, created_at);
create index if not exists workout_logs_user_cycle on public.workout_logs (user_id, cycle_number, week_phase);
create index if not exists set_logs_exercise on public.set_logs (exercise_id);
create index if not exists body_weight_user_date on public.body_weight (user_id, date desc);
create index if not exists exercises_swap on public.exercises (movement_pattern, muscle_group) where is_global;
create index if not exists feed_posts_user_created on public.feed_posts (user_id, created_at desc);
create index if not exists feed_cheers_post on public.feed_cheers (post_id);

-- ------------------------------------------------- dedupe global exercises
-- If seed ever ran twice, global exercise names got duplicated. Re-point
-- any references to one keeper per name, then delete the extras.
with keepers as (
  select distinct on (name) id as keep_id, name
  from public.exercises where is_global
  order by name, id
),
dups as (
  select e.id as dup_id, k.keep_id
  from public.exercises e
  join keepers k on k.name = e.name
  where e.is_global and e.id <> k.keep_id
)
update public.program_exercises pe set exercise_id = d.keep_id
from dups d where pe.exercise_id = d.dup_id;

with keepers as (
  select distinct on (name) id as keep_id, name
  from public.exercises where is_global
  order by name, id
),
dups as (
  select e.id as dup_id, k.keep_id
  from public.exercises e
  join keepers k on k.name = e.name
  where e.is_global and e.id <> k.keep_id
)
update public.set_logs sl set exercise_id = d.keep_id
from dups d where sl.exercise_id = d.dup_id;

with keepers as (
  select distinct on (name) id as keep_id, name
  from public.exercises where is_global
  order by name, id
),
dups as (
  select e.id as dup_id, k.keep_id
  from public.exercises e
  join keepers k on k.name = e.name
  where e.is_global and e.id <> k.keep_id
)
update public.goals g set exercise_id = d.keep_id
from dups d where g.exercise_id = d.dup_id;

delete from public.exercises e
using (
  select distinct on (name) id as keep_id, name
  from public.exercises where is_global
  order by name, id
) k
where e.is_global and e.name = k.name and e.id <> k.keep_id;

create unique index if not exists exercises_global_name
  on public.exercises (name) where is_global;

-- ---------------------------------------------------------- exercise seed
insert into public.exercises (name, short_label, muscle_group, movement_pattern, equipment, unit, rep_profile, cue, is_global) values
('Romanian Deadlift', 'RDL', 'hamstrings', 'hinge', 'barbell', 'kg', 'strength', 'Soft knees, push hips back until the hamstrings load. Bar drags up your legs.', true),
('Dumbbell Romanian Deadlift', 'DB RDL', 'hamstrings', 'hinge', 'dumbbells', 'kg', 'strength', 'Hips back, flat back. Dumbbells slide down the front of your thighs.', true),
('Single-Leg Romanian Deadlift', 'SL RDL', 'hamstrings', 'hinge', 'dumbbells', 'kg', 'strength', 'Square hips, slight knee bend. Reach long — balance comes from the glute.', true),
('Stiff-Leg Deadlift', 'SLDL', 'hamstrings', 'hinge', 'barbell', 'kg', 'strength', 'Straighter knees than an RDL. Stop where your back wants to round.', true),
('Good Morning', null, 'hamstrings', 'hinge', 'barbell', 'kg', 'strength', 'Bar on the back, bow forward from the hips. Light weight, big stretch.', true),
('Lying Leg Curl', null, 'hamstrings', 'hinge', 'machine', 'kg', 'pump', 'Hips pressed down. Curl slow, lower slower.', true),
('Seated Leg Curl', null, 'hamstrings', 'hinge', 'machine', 'kg', 'pump', 'Chest tall against the pad. Full stretch at the top of every rep.', true),
('Cable Pull-Through', null, 'glutes', 'hinge', 'cable', 'kg', 'pump', 'Face away, rope between legs. Hinge back, then snap hips through and squeeze.', true),
('Back Extension', 'GLUTE EXT', 'glutes', 'hinge', 'bodyweight', 'kg', 'pump', 'Round the upper back slightly, tuck chin. Lift with glutes, not lower back.', true),
('Kettlebell Swing', null, 'glutes', 'hinge', 'kettlebell', 'kg', 'pump', 'It is a hinge, not a squat. Hips do the throwing, arms just steer.', true),
('Sumo Deadlift', null, 'glutes', 'hinge', 'barbell', 'kg', 'strength', 'Wide stance, toes out, chest proud. Push the floor away.', true),
('Conventional Deadlift', null, 'glutes', 'hinge', 'barbell', 'kg', 'strength', 'Bar over mid-foot, brace hard. Stand up tall — no jerking off the floor.', true),
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
('Bulgarian Split Squat', 'BSS', 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Long stance, torso leaning slightly forward. The front heel does all the work.', true),
('Walking Lunges', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Long steps, knee kisses the floor. Push through the front heel to travel.', true),
('Reverse Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Step back, drop straight down. Easier on knees, heavier on glutes.', true),
('Curtsy Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Step behind and across. Stay tall — feel the side of the glute.', true),
('Step-Ups', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Bench height, whole foot on the box. Push through the heel — no bouncing.', true),
('Forward Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Controlled step out, push back through the heel to return.', true),
('Smith Machine Split Squat', null, 'glutes', 'lunge', 'smith machine', 'kg', 'strength', 'Front foot far forward, sink straight down. Let the machine balance for you.', true),
('Deficit Reverse Lunge', null, 'glutes', 'lunge', 'dumbbells', 'kg', 'strength', 'Stand on a small plate or step. The extra depth is the point — go slow.', true),
('Back Squat', null, 'glutes', 'squat', 'barbell', 'kg', 'strength', 'Brace, sit between your hips. Depth over load — hips below parallel.', true),
('Goblet Squat', null, 'glutes', 'squat', 'dumbbell', 'kg', 'strength', 'Dumbbell at chest, elbows inside knees at the bottom. Stay upright.', true),
('Smith Machine Squat', null, 'glutes', 'squat', 'smith machine', 'kg', 'strength', 'Feet slightly forward of the bar. Sit back into it — glutes take over.', true),
('Hack Squat', null, 'glutes', 'squat', 'machine', 'kg', 'strength', 'Back flat on the pad, full depth. Drive evenly through the whole foot.', true),
('Leg Press', 'GLUTE PRESS', 'glutes', 'squat', 'machine', 'kg', 'strength', 'Feet high and wide on the platform for glute bias. Deep, controlled reps.', true),
('Sumo Squat', null, 'glutes', 'squat', 'dumbbell', 'kg', 'strength', 'Wide stance, toes out, dumbbell hanging heavy. Sink straight down.', true),
('Box Squat', null, 'glutes', 'squat', 'barbell', 'kg', 'strength', 'Sit back to the box, pause a beat, drive up. No rocking.', true),
('Pendulum Squat', null, 'glutes', 'squat', 'machine', 'kg', 'strength', 'Smooth arc, huge range. Stay deep and controlled.', true),
('Seated Hip Abduction Machine', null, 'glutes', 'abduction', 'machine', 'kg', 'pump', 'Press knees out to the sides, pause at the widest point. Lean forward for more glute.', true),
('Standing Cable Hip Abduction', null, 'glutes', 'abduction', 'cable', 'kg', 'pump', 'Cuff at the ankle, lift the leg straight out to the side. Stay tall.', true),
('Banded Lateral Walks', null, 'glutes', 'abduction', 'band', 'kg', 'pump', 'Band above knees, quarter-squat stance. Small lateral steps, constant tension.', true),
('Side-Lying Hip Abduction', null, 'glutes', 'abduction', 'bodyweight', 'kg', 'pump', 'Top leg slightly behind you, toes down. Lift with the side of the glute.', true),
('Banded Clamshells', null, 'glutes', 'abduction', 'band', 'kg', 'pump', 'Heels together, open the top knee against the band. Slow and strict.', true),
('Lat Pulldown', null, 'back', 'pull', 'cable', 'kg', 'strength', 'Pull the bar to the collarbone, elbows down and in. Chest stays proud.', true),
('Close-Grip Lat Pulldown', null, 'back', 'pull', 'cable', 'kg', 'strength', 'Neutral close grip. Pull elbows to your ribs, stretch fully at the top.', true),
('Assisted Pull-Up', null, 'back', 'pull', 'machine', 'kg', 'strength', 'Full hang at the bottom, chin over bar at the top. Log the assist weight.', true),
('Seated Cable Row', null, 'back', 'pull', 'cable', 'kg', 'strength', 'Tall posture, pull the handle to your navel. Squeeze shoulder blades together.', true),
('Single-Arm Dumbbell Row', null, 'back', 'pull', 'dumbbell', 'kg', 'strength', 'Hand on bench, flat back. Pull the elbow to your hip, not your shoulder.', true),
('Chest-Supported Row', null, 'back', 'pull', 'dumbbells', 'kg', 'strength', 'Chest glued to the incline pad. No cheating — just lats and rhomboids.', true),
('Machine Row', null, 'back', 'pull', 'machine', 'kg', 'strength', 'Drive elbows back, pause, control the stretch forward.', true),
('Straight-Arm Pulldown', null, 'back', 'pull', 'cable', 'kg', 'pump', 'Arms long, sweep the bar to your thighs. Feel the lats the whole way.', true),
('Bicep Curls', null, 'arms', 'pull', 'dumbbells', 'kg', 'pump', 'Elbows pinned at your sides. Curl up, lower for three seconds.', true),
('Hammer Curls', null, 'arms', 'pull', 'dumbbells', 'kg', 'pump', 'Neutral grip, no swinging. Slim strong arms are built slow.', true),
('Cable Curls', null, 'arms', 'pull', 'cable', 'kg', 'pump', 'Constant tension top to bottom. Stand a step back from the stack.', true),
('EZ-Bar Curls', null, 'arms', 'pull', 'barbell', 'kg', 'pump', 'Comfortable angled grip. Squeeze at the top, full stretch at the bottom.', true),
('Dumbbell Shoulder Press', null, 'shoulders', 'push', 'dumbbells', 'kg', 'strength', 'Light and strict. Press to lockout without flaring the ribs.', true),
('Machine Shoulder Press', null, 'shoulders', 'push', 'machine', 'kg', 'strength', 'Settle into the seat, press smooth. No lockout slamming.', true),
('Arnold Press', null, 'shoulders', 'push', 'dumbbells', 'kg', 'strength', 'Rotate palms as you press. Light weight, full rotation.', true),
('Lateral Raises', null, 'shoulders', 'push', 'dumbbells', 'kg', 'pump', 'Lead with the elbows, stop at shoulder height. Lighter than you think.', true),
('Cable Lateral Raises', null, 'shoulders', 'push', 'cable', 'kg', 'pump', 'Cable behind the body. Constant tension — strict, floaty reps.', true),
('Machine Lateral Raise', null, 'shoulders', 'push', 'machine', 'kg', 'pump', 'Pads at the elbows, raise to parallel. Pause briefly at the top.', true),
('Dumbbell Bench Press', null, 'chest', 'push', 'dumbbells', 'kg', 'strength', 'Shoulder blades pinned back, feet planted. Lower with control, press up and slightly in.', true),
('Push-Up', null, 'chest', 'push', 'bodyweight', 'kg', 'strength', 'One straight line head to heels. Chest to the floor, elbows ~45°. Knees down is still a push-up.', true),
('Machine Chest Press', null, 'chest', 'push', 'machine', 'kg', 'strength', 'Handles at mid-chest height. Press smooth, stretch wide on the return.', true),
('Incline Dumbbell Press', null, 'chest', 'push', 'dumbbells', 'kg', 'strength', 'Low incline. Press up and together, lower to a deep comfortable stretch.', true),
('Triceps Rope Pushdown', null, 'arms', 'push', 'cable', 'kg', 'pump', 'Elbows pinned, split the rope at the bottom. Full extension every rep.', true),
('Overhead Cable Triceps Extension', null, 'arms', 'push', 'cable', 'kg', 'pump', 'Face away, arms overhead. Big stretch behind the head, press to lockout.', true),
('Skullcrushers', null, 'arms', 'push', 'barbell', 'kg', 'pump', 'Lower to the forehead, elbows still. Light bar, perfect reps.', true),
('Bench Dips', null, 'arms', 'push', 'bodyweight', 'kg', 'pump', 'Hands on the bench behind you, hips close. Elbows point straight back.', true),
('Cable Crunch', null, 'core', 'core', 'cable', 'kg', 'pump', 'Kneel, rope at your ears. Crunch ribs to hips — the hips do not move.', true),
('Pallof Press', null, 'core', 'core', 'cable', 'kg', 'pump', 'Press the handle straight out and resist the twist. Breathe.', true),
('Plank with Reach', null, 'core', 'core', 'bodyweight', 's', 'timed', 'From a plank, reach one arm forward without the hips tipping. Log seconds.', true),
('Dead Bug', null, 'core', 'core', 'bodyweight', 'kg', 'pump', 'Lower back pressed into the floor. Opposite arm and leg, slow.', true),
('Hanging Knee Raise', null, 'core', 'core', 'bodyweight', 'kg', 'pump', 'Knees to chest with a posterior tilt at the top. No swinging.', true),
('Ab Wheel Rollout', null, 'core', 'core', 'wheel', 'kg', 'pump', 'Roll out only as far as the lower back stays flat. Earn the range.', true),
('Side Plank', null, 'core', 'core', 'bodyweight', 's', 'timed', 'Straight line ear to ankle. Lift the hip away from the floor. Log seconds.', true),
('Hollow Hold', null, 'core', 'core', 'bodyweight', 's', 'timed', 'Lower back pressed down, arms and legs long. Log seconds.', true),
('Weighted Decline Sit-Up', null, 'core', 'core', 'dumbbell', 'kg', 'pump', 'Plate at the chest. Curl up one vertebra at a time.', true),
('Calf Raises', null, 'calves', 'accessory', 'machine', 'kg', 'pump', 'Pause at the deep stretch, drive to your tiptoes. Full range, no bouncing.', true),
('Seated Calf Raise', null, 'calves', 'accessory', 'machine', 'kg', 'pump', 'Slow stretch at the bottom — that is where calves grow.', true),
('Smith Machine Calf Raise', null, 'calves', 'accessory', 'smith machine', 'kg', 'pump', 'Balls of feet on a plate, full stretch, full squeeze.', true),
('Leg Press Calf Raise', null, 'calves', 'accessory', 'machine', 'kg', 'pump', 'Press with the balls of your feet only. Knees stay softly locked.', true),
-- Spartan additions (push · chest/shoulders/arms, pull · back/shoulders)
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

-- Make sure rep profiles are right even if exercises predate this script.
update public.exercises set rep_profile = 'timed' where unit = 's' and rep_profile <> 'timed';
update public.exercises set rep_profile = 'pump' where unit = 'kg' and rep_profile <> 'pump' and name in (
  'Cable Pull-Through','Back Extension','Kettlebell Swing','Lying Leg Curl','Seated Leg Curl',
  'Single-Leg Hip Thrust','Frog Pumps','Cable Kickbacks','Cable Donkey Kicks','Machine Kickback',
  'Dumbbell Glute Bridge','Seated Hip Abduction Machine','Standing Cable Hip Abduction',
  'Banded Lateral Walks','Side-Lying Hip Abduction','Banded Clamshells','Straight-Arm Pulldown',
  'Bicep Curls','Hammer Curls','Cable Curls','EZ-Bar Curls',
  'Lateral Raises','Cable Lateral Raises','Machine Lateral Raise',
  'Triceps Rope Pushdown','Overhead Cable Triceps Extension','Skullcrushers','Bench Dips',
  'Cable Crunch','Pallof Press','Dead Bug','Hanging Knee Raise','Ab Wheel Rollout',
  'Weighted Decline Sit-Up','Calf Raises','Seated Calf Raise','Smith Machine Calf Raise',
  'Leg Press Calf Raise'
);

-- ------------------------------------------------ template program (once)
with prog as (
  insert into public.programs (user_id, name, weeks, days_per_week, active)
  select null, 'Lean & Sculpted', 3, 5, true
  where not exists (
    select 1 from public.programs where user_id is null and name = 'Lean & Sculpted')
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
  (1, 1, 'Romanian Deadlift'),
  (1, 2, 'Hip Thrust'),
  (1, 3, 'Bulgarian Split Squat'),
  (1, 4, 'Cable Donkey Kicks'),
  (1, 5, 'Seated Hip Abduction Machine'),
  (1, 6, 'Lying Leg Curl'),
  (2, 1, 'Lat Pulldown'),
  (2, 2, 'Dumbbell Bench Press'),
  (2, 3, 'Dumbbell Shoulder Press'),
  (2, 4, 'Lateral Raises'),
  (2, 5, 'Triceps Rope Pushdown'),
  (2, 6, 'Bicep Curls'),
  (3, 1, 'Back Squat'),
  (3, 2, 'Walking Lunges'),
  (3, 3, 'Leg Press'),
  (3, 4, 'Hip Thrust Machine'),
  (3, 5, 'Standing Cable Hip Abduction'),
  (3, 6, 'Calf Raises'),
  (4, 1, 'Close-Grip Lat Pulldown'),
  (4, 2, 'Single-Arm Dumbbell Row'),
  (4, 3, 'Back Extension'),
  (4, 4, 'Cable Crunch'),
  (4, 5, 'Pallof Press'),
  (4, 6, 'Plank with Reach'),
  (5, 1, 'Sumo Squat'),
  (5, 2, 'Step-Ups'),
  (5, 3, 'Cable Kickbacks'),
  (5, 4, 'Frog Pumps'),
  (5, 5, 'Banded Lateral Walks'),
  (5, 6, 'Glute Bridge Hold')
) as x(day_idx, sort, exercise_name) on x.day_idx = days.day_index
join public.exercises e on e.name = x.exercise_name and e.is_global;

-- Patch programs that were created from the v1 template (template + clones).
update public.program_exercises pe
set exercise_id = (select id from public.exercises where name = 'Lying Leg Curl' and is_global limit 1)
where pe.exercise_id = (select id from public.exercises where name = 'Cable Pull-Through' and is_global limit 1)
  and exists (
    select 1 from public.program_days d
    where d.id = pe.program_day_id and d.name = 'Glutes & Hamstrings');

update public.program_exercises pe
set exercise_id = (select id from public.exercises where name = 'Dumbbell Bench Press' and is_global limit 1)
where pe.exercise_id = (select id from public.exercises where name = 'Seated Cable Row' and is_global limit 1)
  and exists (
    select 1 from public.program_days d
    where d.id = pe.program_day_id and d.name = 'Upper Body Lean');

update public.program_exercises pe
set sort = x.sort
from (values
  ('Sumo Squat', 1), ('Step-Ups', 2), ('Cable Kickbacks', 3),
  ('Frog Pumps', 4), ('Banded Lateral Walks', 5), ('Glute Bridge Hold', 6)
) as x(name, sort)
join public.exercises e on e.name = x.name and e.is_global
join public.program_days d on d.name = 'Booty Volume'
where pe.exercise_id = e.id and pe.program_day_id = d.id;

-- ----------------------------------------------------------- quotes (once)
insert into public.quotes (text, author)
select q, a from (values
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
  ('Soft days build strong years.', null)
) as v(q, a)
where not exists (select 1 from public.quotes);

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


-- ------------------------------------------------------ instruction videos
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/KecWzqYscYc' where name = 'Romanian Deadlift' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/qFxTNOiQIAU' where name = 'Hip Thrust' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/DeCnHqrN22U' where name = 'Bulgarian Split Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/3nDCUmratPs' where name = 'Cable Donkey Kicks' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/I4ApZY585nE' where name = 'Seated Hip Abduction Machine' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/yXopOhzEoeo' where name = 'Cable Pull-Through' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/O94yEoGXtBY' where name = 'Lat Pulldown' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/XaHV_8Nbyug' where name = 'Seated Cable Row' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/1jYq9QQEWqE' where name = 'Dumbbell Shoulder Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/n5dsI9qQXwY' where name = 'Lateral Raises' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/qHDrQglWgS4' where name = 'Triceps Rope Pushdown' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/M2Nbw9tunoY' where name = 'Bicep Curls' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/SbgHegC6lEs' where name = 'Back Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/Pbmj6xPo-Hw' where name = 'Walking Lunges' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/cDGOn-yfKJA' where name = 'Leg Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/6ombApkDsf4' where name = 'Hip Thrust Machine' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/bGlm-qTnfTI' where name = 'Standing Cable Hip Abduction' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/Xa18jxyeSnM' where name = 'Calf Raises' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/mUoo2l-p8Hw' where name = 'Close-Grip Lat Pulldown' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/nMFCMNKnLgQ' where name = 'Single-Arm Dumbbell Row' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/GFqfIInCuUQ' where name = 'Back Extension' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/aBd6T01PBqw' where name = 'Cable Crunch' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/_2xWmYNnFS8' where name = 'Pallof Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/xst2FFsIa74' where name = 'Plank with Reach' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/pcY33kEoKZ4' where name = 'Sumo Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/jbJBXErKD-U' where name = 'Frog Pumps' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/tqECKZxlCKE' where name = 'Step-Ups' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/bVrmtCI00Ys' where name = 'Cable Kickbacks' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/PhNkkOieB-8' where name = 'Banded Lateral Walks' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/rVdk_9rwRIM' where name = 'Glute Bridge Hold' and is_global;

-- ----------------------------------------------------- realtime publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'feed_cheers'
  ) then
    alter publication supabase_realtime add table public.feed_cheers;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'feed_posts'
  ) then
    alter publication supabase_realtime add table public.feed_posts;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'feed_comments'
  ) then
    alter publication supabase_realtime add table public.feed_comments;
  end if;
end $$;

-- ---------------------------------------------------------------- buckets
insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false)
on conflict (id) do nothing;
insert into storage.buckets (id, name, public)
values ('feed-photos', 'feed-photos', false)
on conflict (id) do nothing;

update storage.buckets
set file_size_limit = 10485760, -- 10 MB
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif']
where id in ('progress-photos', 'feed-photos');

-- Storage POLICIES live in storage_policies.sql (run separately — on some
-- Supabase projects they must be created via Dashboard → Storage → Policies).
