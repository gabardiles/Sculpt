-- Security hardening from the pre-tester audit.

-- H1: users could UPDATE any column of their own profile row — including
-- is_admin (privilege escalation → invite-only bypass). Column-level
-- grants: authenticated users may only change their name.
revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;
grant update (name) on public.profiles to authenticated;

-- M2/L9: cheers were readable (and broadcast over Realtime) for ANY post,
-- not just visible ones. Gate both read and insert on post visibility.
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

-- M3: workout logs could reference another user's program day. Constrain
-- writes to days inside the caller's own programs.
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

-- M5: cap upload size and restrict types on both photo buckets.
update storage.buckets
set file_size_limit = 10485760, -- 10 MB
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif']
where id in ('progress-photos', 'feed-photos');
