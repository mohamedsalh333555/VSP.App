-- VSP STAGING-only: RLS policy overlap classifications, no data or DDL.
-- Groupings intentionally differ from Supabase Advisor's role inheritance.
with p as (
 select tablename,policyname,cmd,roles::text as roles,permissive,
  coalesce(qual,'') as q,coalesce(with_check,'') as ck
 from pg_policies where schemaname='public'
), exact_duplicate as (
 select tablename,cmd,roles,permissive,q,ck,count(*) as n
 from p group by tablename,cmd,roles,permissive,q,ck having count(*)>1
), literal_select_overlap as (
 select tablename,roles,count(*) as n from p
 where permissive='PERMISSIVE' and cmd='SELECT'
 group by tablename,roles having count(*)>1
), actions as (
 select tablename,policyname,roles::text as roles,a.action
 from pg_policies p cross join lateral
  (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) a(action)
 where schemaname='public' and permissive='PERMISSIVE'
  and (cmd='ALL' or cmd=a.action)
), expanded as (
 select tablename,roles,action,count(*) as n from actions
 group by tablename,roles,action having count(*)>1
)
select
 (select count(*) from exact_duplicate) exact_definition_duplicates,
 (select count(*) from literal_select_overlap) literal_role_select_overlap_groups,
 (select count(*) from expanded) expanded_action_overlap_groups,
 (select count(distinct tablename) from expanded) expanded_tables,
 (select count(*) from expanded where action='SELECT') expanded_select_groups,
 (select count(*) from expanded where action='INSERT') expanded_insert_groups,
 (select count(*) from expanded where action='UPDATE') expanded_update_groups,
 (select count(*) from expanded where action='DELETE') expanded_delete_groups;

-- Grant and RLS access-check metadata only; no field content.
select
 has_table_privilege('authenticated','public.teams','SELECT') as auth_all_columns,
 has_column_privilege('authenticated','public.teams','captain_phone','SELECT') as auth_can_read_captain_phone,
 has_column_privilege('authenticated','public.teams','active_invite_code','SELECT') as auth_can_read_invite_code,
 has_table_privilege('anon','public.teams','SELECT') as anon_table_select;
