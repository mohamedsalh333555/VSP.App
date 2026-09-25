-- Final privacy policy correction -- 2026-09-26
drop policy if exists users_select_policy on public.users;
create policy users_select_policy on public.users for select to authenticated
using (id=auth.uid() or public.is_admin_or_cofounder(auth.uid()));

drop policy if exists "Public Access for Owner Documents" on storage.objects;
drop policy if exists "Owner access own documents or Admin" on storage.objects;
create policy "Owner access own documents or Admin"
on storage.objects for select to authenticated
using (
  bucket_id='owner_documents' and (
    (auth.uid())::text=(storage.foldername(name))[1]
    or exists(select 1 from public.users u where u.id=auth.uid()
      and u.role in ('admin','co_founder','cofounder','super_admin'))
  )
);