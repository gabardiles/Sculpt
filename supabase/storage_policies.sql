-- ============================================================================
-- Sculpt — storage policies. Run AFTER setup_all.sql, as its own query.
--
-- Kept separate on purpose: on newer Supabase projects the SQL editor may
-- not own storage.objects, and a failure here would otherwise roll back the
-- whole setup. If this file errors with "must be owner of table objects",
-- create the same four policies in Dashboard → Storage → Policies instead —
-- the USING / WITH CHECK expressions to paste are exactly the ones below.
-- ============================================================================

-- progress-photos: strictly private to the owner.
drop policy if exists "photos own read" on storage.objects;
create policy "photos own read" on storage.objects
  for select using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "photos own insert" on storage.objects;
create policy "photos own insert" on storage.objects
  for insert with check (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "photos own delete" on storage.objects;
create policy "photos own delete" on storage.objects
  for delete using (
    bucket_id = 'progress-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);

-- feed-photos: owner writes/deletes; friends may view.
drop policy if exists "feed photos own write" on storage.objects;
create policy "feed photos own write" on storage.objects
  for insert with check (
    bucket_id = 'feed-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "feed photos own delete" on storage.objects;
create policy "feed photos own delete" on storage.objects
  for delete using (
    bucket_id = 'feed-photos'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "feed photos friends read" on storage.objects;
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
