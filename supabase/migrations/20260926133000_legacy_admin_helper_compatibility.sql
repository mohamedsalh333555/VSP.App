-- Legacy admin helper compatibility -- 2026-09-26
create or replace function public.is_admin_or_founder(p_user_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $f$ select public.is_admin_or_cofounder(p_user_id); $f$;
revoke all on function public.is_admin_or_founder(uuid) from public,anon;
grant execute on function public.is_admin_or_founder(uuid) to authenticated,service_role;