-- A week counts as complete at 3 of 5 sessions (checkbox); all 5 earns a
-- star. Closing a week early is an explicit choice, recorded here.
create table if not exists public.week_closures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  cycle_number int not null,
  week_phase text not null check (week_phase in ('light','medium','hard')),
  created_at timestamptz not null default now(),
  unique (user_id, cycle_number, week_phase)
);

alter table public.week_closures enable row level security;

drop policy if exists "week_closures own" on public.week_closures;
create policy "week_closures own" on public.week_closures
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
