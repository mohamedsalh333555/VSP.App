-- Read-only release audit: run against a target project before enabling the
-- Team Skills feature. SELECT/pg_catalog inspection only; no writes to data
-- or migration history. This is a guardrail, NOT a replacement for E2E JWT tests.
do $security_audit$
declare table_count integer;view_count integer;rpc_count integer;
begin
 select count(*) into table_count
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname like 'team_skills_%'
   and c.relkind='r';
 if table_count<10 then
   raise exception 'Team Skills tables missing: %',table_count;
 end if;

 if exists(
   select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname like 'team_skills_%'
     and c.relkind='r' and not c.relrowsecurity
 ) then raise exception 'Team Skills API table without RLS';end if;

 select count(*) into view_count
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname like 'team_skills_%'
   and c.relkind='v';
 if view_count<>3 then
   raise exception 'Expected exactly three Team Skills public report views; got %',view_count;
 end if;
 if exists(
   select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname like 'team_skills_%'
     and c.relkind='v'
     and not (coalesce(c.reloptions,array[]::text[]) @> array['security_invoker=true'])
 ) then raise exception 'Team Skills view missing security_invoker';end if;

 select count(*) into rpc_count
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname like 'team_skills_%'
   and p.prokind='f';
 if rpc_count<18 then raise exception 'Team Skills exposed API contract incomplete';end if;

 if exists(
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname like 'team_skills_%'
     and has_function_privilege('anon',p.oid,'EXECUTE')
 ) then raise exception 'Anonymous can execute Team Skills privileged RPC';end if;

 if exists(
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname like 'team_skills_%'
     and p.prosecdef and has_function_privilege('authenticated',p.oid,'EXECUTE')
     and position('auth.uid()' in p.prosrc)=0
 ) then raise exception 'Team Skills privileged RPC missing auth.uid identity check';end if;

 -- SQL body scans are defense-in-depth warnings, not a proof of correct
 -- authorization: real multi-account RPC tests remain mandatory.
 if exists(
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname like 'team_skills_%'
     and p.proname not in ('team_skills_register',
                           'team_skills_record_score',
                           'team_skills_record_goalkeeper')
     and position('vsp_skills_private.is_admin()' in p.prosrc)=0
 ) then raise exception 'Team Skills administrative RPC missing is_admin guard';end if;

 if exists(
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.proname in ('team_skills_record_score','team_skills_record_goalkeeper')
     and (position('role=' in p.prosrc)=0
       or position('judge' in p.prosrc)=0
       or position('vsp_skills_private.is_admin()' in p.prosrc)=0)
 ) then raise exception 'Assigned judge RPC missing per-cup role checks';end if;

 if exists(
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='team_skills_register'
     and (position('captain_id' in p.prosrc)=0
       or position('Captain only' in p.prosrc)=0)
 ) then raise exception 'Captain registration RPC missing canonical team ownership';end if;

 if exists(
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='vsp_skills_private'
     and has_function_privilege('anon',p.oid,'EXECUTE')
 ) then raise exception 'Anonymous can invoke internal Team Skills helper';end if;

 raise notice 'PASS: % Team Skills RLS tables, % invoker views and % authenticated-only RPCs',
   table_count,view_count,rpc_count;
end $security_audit$;
