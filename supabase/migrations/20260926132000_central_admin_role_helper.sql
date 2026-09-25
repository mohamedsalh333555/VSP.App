-- Central admin role helper coherence -- 2026-09-26
create or replace function public.is_admin_or_cofounder(p_user_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $f$
  select exists(
    select 1 from public.users
    where id=p_user_id
      and coalesce(is_blocked,false)=false
      and role in ('admin','co_founder','cofounder','super_admin')
  );
$f$;
revoke all on function public.is_admin_or_cofounder(uuid) from public,anon;
grant execute on function public.is_admin_or_cofounder(uuid) to authenticated;
grant execute on function public.is_admin_or_cofounder(uuid) to service_role;