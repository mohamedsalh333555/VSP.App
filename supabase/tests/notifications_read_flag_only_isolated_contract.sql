do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;
end $roles$;
create schema auth;
create function auth.role() returns text language sql stable as $$
 select nullif(current_setting('request.jwt.claim.role',true),'')
$$;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create schema vsp_notifications_private;
create table public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid,title text,
 body text,message text,type text,is_read boolean default false,
 booking_id uuid,metadata jsonb,created_at timestamptz default now()
);
alter table public.notifications enable row level security;
create policy notice_insert on public.notifications for insert to authenticated
with check(user_id=(select auth.uid()));
create policy notice_select on public.notifications for select to authenticated
using(user_id=(select auth.uid()));
create policy notice_update on public.notifications for update to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
grant usage on schema public,auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function auth.role() to authenticated;
grant select,insert,update on public.notifications to authenticated;
-- ACTUAL_NOTIFICATION_READ_FLAG_GUARD

insert into public.notifications(id,user_id,title,body,message,type,booking_id,metadata)
values('00000000-0000-0000-0000-000000001001',
 '00000000-0000-0000-0000-000000000101',
 'Paymob verified','paid','paid','payment_received',
 '00000000-0000-0000-0000-000000002001',
 '{"source":"booking","event":"paymob_payment_confirmed"}');
set role authenticated;
select set_config('request.jwt.claim.role','authenticated',false);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',false);
-- A real notification must remain markable as read.
update public.notifications set is_read=true
where id='00000000-0000-0000-0000-000000001001';
do $client_edits$
declare col text; denied boolean;
begin
 for col in select unnest(array[
  'title','body','message','type','booking_id','metadata','created_at','user_id'
 ]) loop
   denied:=false;
   begin
    execute format('update public.notifications set %I = %s where id = %L',
      col,
      case col
       when 'title' then quote_literal('forged')
       when 'body' then quote_literal('forged')
       when 'message' then quote_literal('forged')
       when 'type' then quote_literal('refund_success')
       when 'booking_id' then quote_literal('00000000-0000-0000-0000-000000002002')
       when 'metadata' then quote_literal('{"event":"refund_success"}')||'::jsonb'
       when 'created_at' then quote_literal('2024-01-01')||'::timestamptz'
       when 'user_id' then quote_literal('00000000-0000-0000-0000-000000000102')
      end,
      '00000000-0000-0000-0000-000000001001');
   exception when insufficient_privilege then denied:=true;
   end;
   if not denied then
    raise exception 'CLIENT_EDITED_IMMUTABLE_NOTIFICATION_FIELD: %',col;
   end if;
 end loop;
end $client_edits$;
-- User B must never be able to mark user A's notice read.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000102',false);
update public.notifications set is_read=false
where id='00000000-0000-0000-0000-000000001001';
reset role;
do $result$ begin
 if (select count(*) from public.notifications)<>1
 or (select is_read from public.notifications where id=
  '00000000-0000-0000-0000-000000001001') is distinct from true
 or (select type from public.notifications where id=
  '00000000-0000-0000-0000-000000001001')<>'payment_received'
 then raise exception 'READ_ONLY_NOTIFICATION_UPDATE_GUARD_INCORRECT';end if;
 if has_function_privilege('anon',
   'vsp_notifications_private.guard_client_notification_edits()','EXECUTE')
 or has_function_privilege('authenticated',
   'vsp_notifications_private.guard_client_notification_edits()','EXECUTE')
 then raise exception 'NOTIFICATION_EDIT_TRIGGER_EXTERNALLY_CALLABLE';end if;
end $result$;
