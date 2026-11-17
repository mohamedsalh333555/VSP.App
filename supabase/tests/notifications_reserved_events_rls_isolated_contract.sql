-- Isolated actual policy contract: user self-inserts still permitted
-- for generic messages, not forged server financial/result events.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create function public.is_admin_or_cofounder(uuid) returns boolean
language sql stable as $$
  select $1='00000000-0000-0000-0000-000000000099'::uuid
$$;
create table public.notifications(
 id bigint generated always as identity primary key,user_id uuid not null,
 title text,type text,booking_id uuid,metadata jsonb);
alter table public.notifications enable row level security;
grant usage on schema public to authenticated,anon;
grant usage on schema auth to authenticated,anon;
grant execute on function auth.uid() to authenticated,anon;
grant execute on function public.is_admin_or_cofounder(uuid) to authenticated,anon;
grant insert on public.notifications to authenticated;
create policy notifications_insert_secure
on public.notifications for insert to authenticated
with check (
  public.is_admin_or_cofounder((select auth.uid()))
  or user_id=(select auth.uid())
);
-- ACTUAL_RESERVED_EVENT_RLS_MIGRATION

set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',false);
-- Own normal event works; application notifications do not stop globally.
insert into public.notifications(user_id,title,type,metadata)
values('00000000-0000-0000-0000-000000000101',
       'رسالة عادية','info','{"source":"generic"}');
do $negative$
declare denied boolean; v_type text; v_source text; v_event text;
begin
 for v_type,v_source,v_event in
  select * from (values
    ('payment_received','generic',''),
    ('deposit_received','generic',''),
    ('booking_confirmed','generic',''),
    ('refund_success','generic',''),
    ('refund_pending','generic',''),
    ('info','booking','paymob_payment_confirmed'),
    ('info','booking','cash_booking_confirmed'),
    ('info','booking','booking_cancelled'),
    ('info','team_skills_cup','phase_score_approved'),
    ('info','team_skills_cup','knockout_advancement'),
    ('info','team_skills_cup','award_announced')
  ) as v(a,b,c)
 loop
   denied:=false;
   begin
     insert into public.notifications(user_id,title,type,metadata)
     values('00000000-0000-0000-0000-000000000101',
            'fake server receipt',v_type,
            jsonb_build_object('source',v_source,'event',v_event));
   exception when insufficient_privilege then
     denied:=true;
   end;
   if not denied then
     raise exception 'CLIENT_FORGED_RESTRICTED_NOTICE: %/%/%',
       v_type,v_source,v_event;
   end if;
 end loop;
end $negative$;
-- Trusted platform-admin policy exemption (actual staging predicate is
-- checked separately); ordinary user was always denied above.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000099',false);
insert into public.notifications(user_id,title,type,metadata)
values('00000000-0000-0000-0000-000000000099',
       'admin issued receipt','payment_received',
       '{"source":"booking","event":"paymob_payment_confirmed"}');
reset role;
-- A server trigger can insert reserved notice with bypass-RLS semantics;
-- this fixture's postgres connection is intentionally not a client JWT.
insert into public.notifications(user_id,title,type,metadata)
values('00000000-0000-0000-0000-000000000101',
       'server receipt','payment_received',
       '{"source":"booking","event":"paymob_payment_confirmed"}');
do $post$
begin
 if (select count(*) from public.notifications)<>3
 or (select count(*) from public.notifications where title='fake server receipt')<>0
 or (select permissive from pg_policies
   where schemaname='public' and tablename='notifications'
     and policyname='notifications_reserved_events_server_only')<>'RESTRICTIVE'
 then raise exception 'NOTIFICATION_RESERVED_EVENT_RLS_UNSAFE';end if;
end $post$;
