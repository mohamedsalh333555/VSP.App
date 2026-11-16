-- Disposable SQL contract for actual Team Skills read-only view migration.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then
   create role authenticated;end if;
 if not exists(select 1 from pg_roles where rolname='anon') then
   create role anon;end if;
end $roles$;
create view public.team_skills_leaderboard as select 1::integer as points;
create view public.team_skills_team_history as select 1::integer as team_id;
create view public.team_skills_player_history as select 1::integer as player_id;

-- Recreate the unsafe inherited grants, then execute the actual migration.
grant all on public.team_skills_leaderboard,
 public.team_skills_team_history,
 public.team_skills_player_history to authenticated;
-- TEAM_SKILLS_VIEWS_READONLY_MIGRATION

do $verify$
declare v_name text; v_oid oid;
begin
 foreach v_name in array array[
  'team_skills_leaderboard',
  'team_skills_team_history',
  'team_skills_player_history'
 ] loop
   select c.oid into v_oid from pg_class c
   join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname=v_name and c.relkind='v';
   if v_oid is null then raise exception 'Missing view %',v_name;end if;
   if not has_table_privilege('authenticated',v_oid,'SELECT')
   then raise exception 'Missing read on %',v_name;end if;
   if has_table_privilege('authenticated',v_oid,'INSERT')
      or has_table_privilege('authenticated',v_oid,'UPDATE')
      or has_table_privilege('authenticated',v_oid,'DELETE')
      or has_table_privilege('authenticated',v_oid,'TRUNCATE')
      or has_table_privilege('authenticated',v_oid,'REFERENCES')
      or has_table_privilege('authenticated',v_oid,'TRIGGER')
   then raise exception 'Unsafe write privilege remains on %',v_name;end if;
   if has_table_privilege('anon',v_oid,'SELECT')
   then raise exception 'Anonymous read exposed on %',v_name;end if;
   if not exists(select 1 from pg_class where oid=v_oid
     and 'security_invoker=true'=any(reloptions))
   then raise exception 'View bypasses caller RLS: %',v_name;end if;
 end loop;
end $verify$;

begin;
set local role authenticated;
select count(*) as visible_leaderboard from public.team_skills_leaderboard;
select count(*) as visible_team_history from public.team_skills_team_history;
select count(*) as visible_player_history from public.team_skills_player_history;
rollback;
