-- Storage ownership hardening -- 2026-09-26

drop policy if exists "stadium_images_auth_upload" on storage.objects;
create policy "stadium_images_owner_upload"
on storage.objects for insert to authenticated
with check (bucket_id = 'stadium-images' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Authenticated upload profile pictures" on storage.objects;
create policy "profile_pictures_owner_upload"
on storage.objects for insert to authenticated
with check (bucket_id = 'profile-pictures' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Owner update own stadium images" on storage.objects;
create policy "Owner update own stadium images"
on storage.objects for update to authenticated
using (
  bucket_id = 'stadium-images' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or owner = auth.uid()
    or exists (select 1 from public.users u where u.id = auth.uid() and u.role in ('admin','co_founder','cofounder','super_admin'))
  )
)
with check (
  bucket_id = 'stadium-images' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or owner = auth.uid()
    or exists (select 1 from public.users u where u.id = auth.uid() and u.role in ('admin','co_founder','cofounder','super_admin'))
  )
);