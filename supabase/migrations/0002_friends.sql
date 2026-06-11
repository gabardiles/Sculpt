-- Sculpt — friends & shared feed
-- Add friends with a short code; share a feed of non-sensitive wins:
-- completed workouts, new PBs, gym photos, small messages.
-- Body weight and progress photos are NEVER shared.

-- Every profile gets a short, shareable friend code.
alter table public.profiles
  add column friend_code text not null unique
  default upper(substring(md5(gen_random_uuid()::text), 1, 6));

-- ----------------------------------------------------------------- friends
-- Mutual: adding by code creates both directions (via the RPC below).
create table public.friends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  friend_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, friend_id),
  check (user_id <> friend_id)
);

alter table public.friends enable row level security;

create policy "friends read own" on public.friends
  for select using (user_id = auth.uid() or friend_id = auth.uid());
-- Unfriending removes both directions; either side may delete either row.
create policy "friends delete own" on public.friends
  for delete using (user_id = auth.uid() or friend_id = auth.uid());
-- No insert policy: rows are only created by the add_friend RPC.

-- Friends can see each other's name + code (nothing else is in profiles).
create policy "profiles friends read" on public.profiles
  for select using (
    exists (
      select 1 from public.friends f
      where f.user_id = auth.uid() and f.friend_id = profiles.id
    )
  );

-- Add a friend by code. SECURITY DEFINER so it can insert the reverse row.
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

-- -------------------------------------------------------------------- feed
create table public.feed_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('workout','pb','photo','message')),
  body text,
  storage_path text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.feed_posts enable row level security;

create policy "feed read self or friends" on public.feed_posts
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.friends f
      where f.user_id = auth.uid() and f.friend_id = feed_posts.user_id
    )
  );
create policy "feed insert own" on public.feed_posts
  for insert with check (user_id = auth.uid());
create policy "feed delete own" on public.feed_posts
  for delete using (user_id = auth.uid());

-- Cheers — one heart per person per post.
create table public.feed_cheers (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

alter table public.feed_cheers enable row level security;

create policy "cheers read visible posts" on public.feed_cheers
  for select using (
    exists (select 1 from public.feed_posts p where p.id = post_id)
  );
create policy "cheers insert own" on public.feed_cheers
  for insert with check (
    user_id = auth.uid()
    and exists (select 1 from public.feed_posts p where p.id = post_id)
  );
create policy "cheers delete own" on public.feed_cheers
  for delete using (user_id = auth.uid());

create index feed_posts_user_created on public.feed_posts (user_id, created_at desc);
create index feed_cheers_post on public.feed_cheers (post_id);

-- ----------------------------------------------------- feed photo storage
insert into storage.buckets (id, name, public)
values ('feed-photos', 'feed-photos', false)
on conflict (id) do nothing;

create policy "feed photos own write" on storage.objects
  for insert with check (
    bucket_id = 'feed-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);
create policy "feed photos own delete" on storage.objects
  for delete using (
    bucket_id = 'feed-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);
create policy "feed photos friends read" on storage.objects
  for select using (
    bucket_id = 'feed-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.friends f
        where f.user_id = auth.uid()
          and f.friend_id::text = (storage.foldername(name))[1]
      )
    )
  );
