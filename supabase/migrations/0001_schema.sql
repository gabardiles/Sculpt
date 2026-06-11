-- Sculpt — schema + RLS
-- Run with: supabase db push  (or paste into the SQL editor)

-- ---------------------------------------------------------------- profiles
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text,
  is_admin boolean not null default false,
  invited_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

-- Auto-create a profile row for every new auth user.
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

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- --------------------------------------------------------------- exercises
create table public.exercises (
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
  is_global boolean not null default false,
  created_by uuid references auth.users (id)
);

-- ---------------------------------------------------------------- programs
-- user_id null = global template (cloned per user at onboarding).
create table public.programs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade,
  name text not null,
  weeks int not null default 3,
  days_per_week int not null default 5,
  active boolean not null default true,
  cycle_floor int not null default 1, -- manual "reset cycle" bumps this
  created_at timestamptz not null default now()
);

create table public.program_days (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete cascade,
  day_index int not null,
  name text not null
);

create table public.program_exercises (
  id uuid primary key default gen_random_uuid(),
  program_day_id uuid not null references public.program_days (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  sort int not null default 0,
  sets int not null default 3
);

-- ------------------------------------------------------------------- logs
create table public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  program_day_id uuid not null references public.program_days (id),
  week_phase text not null check (week_phase in ('light','medium','hard')),
  cycle_number int not null default 1,
  completed_at timestamptz not null default now(),
  feel_rating int check (feel_rating between 1 and 5)
);

create table public.set_logs (
  id uuid primary key default gen_random_uuid(),
  workout_log_id uuid not null references public.workout_logs (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  weight_kg numeric,
  reps int
);

create table public.body_weight (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null default current_date,
  weight_kg numeric not null,
  unique (user_id, date)
);

create table public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  cycle_number int not null default 1,
  week_label text not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create table public.goals (
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

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  author text
);

-- -------------------------------------------------------------------- RLS
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

-- profiles: own row only
create policy "profiles own read" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles own update" on public.profiles
  for update using (auth.uid() = id);

-- exercises: global ones readable by everyone signed in; own custom ones full
create policy "exercises read" on public.exercises
  for select using (is_global or created_by = auth.uid());
create policy "exercises insert own" on public.exercises
  for insert with check (created_by = auth.uid());

-- programs: own rows + global templates (user_id is null) readable
create policy "programs read" on public.programs
  for select using (user_id = auth.uid() or user_id is null);
create policy "programs insert own" on public.programs
  for insert with check (user_id = auth.uid());
create policy "programs update own" on public.programs
  for update using (user_id = auth.uid());

-- program_days / program_exercises: via owning program
create policy "program_days read" on public.program_days
  for select using (exists (
    select 1 from public.programs p
    where p.id = program_id and (p.user_id = auth.uid() or p.user_id is null)));
create policy "program_days write" on public.program_days
  for all using (exists (
    select 1 from public.programs p
    where p.id = program_id and p.user_id = auth.uid()))
  with check (exists (
    select 1 from public.programs p
    where p.id = program_id and p.user_id = auth.uid()));

create policy "program_exercises read" on public.program_exercises
  for select using (exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_id and (p.user_id = auth.uid() or p.user_id is null)));
create policy "program_exercises write" on public.program_exercises
  for all using (exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_id and p.user_id = auth.uid()))
  with check (exists (
    select 1 from public.program_days d join public.programs p on p.id = d.program_id
    where d.id = program_day_id and p.user_id = auth.uid()));

-- logs & personal data: own rows only
create policy "workout_logs own" on public.workout_logs
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "set_logs own" on public.set_logs
  for all using (exists (
    select 1 from public.workout_logs w
    where w.id = workout_log_id and w.user_id = auth.uid()))
  with check (exists (
    select 1 from public.workout_logs w
    where w.id = workout_log_id and w.user_id = auth.uid()));
create policy "body_weight own" on public.body_weight
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "progress_photos own" on public.progress_photos
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "goals own" on public.goals
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- quotes: readable by anyone signed in
create policy "quotes read" on public.quotes
  for select using (auth.role() = 'authenticated');

-- ---------------------------------------------------------------- storage
insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false)
on conflict (id) do nothing;

create policy "photos own read" on storage.objects
  for select using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos own insert" on storage.objects
  for insert with check (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos own delete" on storage.objects
  for delete using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);

-- ----------------------------------------------------------------- indexes
create index workout_logs_user_cycle on public.workout_logs (user_id, cycle_number, week_phase);
create index set_logs_exercise on public.set_logs (exercise_id);
create index body_weight_user_date on public.body_weight (user_id, date desc);
create index exercises_swap on public.exercises (movement_pattern, muscle_group) where is_global;
