-- Push notifications — device token registry (iOS app).
-- Each signed-in device stores its APNs token here so the notify-feed Edge
-- Function can target a member's phones when a friend cheers or comments.
-- Safe to apply to the shared backend; the web app simply never writes here.

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null default 'ios' check (platform in ('ios')),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- A member manages only her own device rows. The Edge Function reads tokens
-- with the service-role key, which bypasses RLS.
drop policy if exists "device_tokens own" on public.device_tokens;
create policy "device_tokens own" on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
