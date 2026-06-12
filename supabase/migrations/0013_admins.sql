-- Sculpt — designate the standing admins (Gabriel + Helena).
--
-- Admin is the `is_admin` flag on public.profiles; it gates the in-app
-- /admin invite screen. We want these two accounts to be admins no matter
-- what — including if their auth account is ever deleted and recreated —
-- so we (1) promote any existing rows now and (2) teach the new-user
-- trigger to auto-promote them on signup.

-- ---------------------------------------------------------------- allowlist
-- Kept inline (no extra table) so this stays a single, re-runnable script.
-- lower()-compared so casing never matters.

-- (1) Promote existing accounts.
update public.profiles p
set is_admin = true
from auth.users u
where p.id = u.id
  and lower(u.email) in (
    'gabriel@ardiles.se',
    'gabriel.ardiles@gmail.com',
    'helena.ardiles@gmail.com'
  );

-- (2) Auto-create the profile row for every new auth user, flipping
--     is_admin on for the allowlisted emails. Never demotes an existing
--     admin (the on-conflict OR preserves a prior true).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, is_admin)
  values (
    new.id,
    lower(new.email) in (
      'gabriel@ardiles.se',
      'gabriel.ardiles@gmail.com',
      'helena.ardiles@gmail.com'
    )
  )
  on conflict (id) do update
    set is_admin = public.profiles.is_admin or excluded.is_admin;
  return new;
end;
$$;
