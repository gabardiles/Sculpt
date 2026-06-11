-- Live cheers: deliver new cheers/messages to friends in real time
-- (Supabase Realtime postgres_changes respects RLS, so subscribers only
-- receive rows they're allowed to see).
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
end $$;

-- Quotes are public pep lines, not user data — open them to anon so the
-- server can cache them once for everyone instead of per-request.
drop policy if exists "quotes read" on public.quotes;
create policy "quotes read" on public.quotes for select using (true);
