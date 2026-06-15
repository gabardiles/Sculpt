-- Sculpt — Green Days (activity + gamification)
-- One denormalised row per member per day powers the whole streak layer:
-- whether she trained, her step count, and the step goal that applied that day.
--   Green = trained OR hit the step goal.
--   Gold  = trained AND hit the step goal.
-- Keeping the day's verdict self-contained here means friends can read a single
-- table for the leaderboard without ever touching each other's workout_logs.
-- Steps are an aggregate daily total — never per-sample health data. Body
-- weight and progress photos remain private, exactly as before.

create table public.activity_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null default current_date,
  steps int not null default 0,
  step_goal int not null default 10000,
  workout_done boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (user_id, date)
);

alter table public.activity_days enable row level security;

-- Own rows: full access. Friends: read-only (for the leaderboard).
create policy "activity own read" on public.activity_days
  for select using (user_id = auth.uid());
create policy "activity friends read" on public.activity_days
  for select using (
    exists (
      select 1 from public.friends f
      where f.user_id = auth.uid() and f.friend_id = activity_days.user_id
    )
  );
create policy "activity insert own" on public.activity_days
  for insert with check (user_id = auth.uid());
create policy "activity update own" on public.activity_days
  for update using (user_id = auth.uid());

create index activity_days_user_date on public.activity_days (user_id, date desc);

-- Member-tunable daily step goal (default 10k), read by both clients.
alter table public.profiles
  add column step_goal int not null default 10000;
