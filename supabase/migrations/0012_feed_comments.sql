-- Comments on feed posts (gym photos, progress, messages). Visibility and
-- insert are gated on the underlying post being visible to the caller —
-- same rule as cheers.
create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

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

create index if not exists feed_comments_post on public.feed_comments (post_id, created_at);

-- Live: deliver new comments to everyone who can see the post.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'feed_comments'
  ) then
    alter publication supabase_realtime add table public.feed_comments;
  end if;
end $$;
