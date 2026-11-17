-- Assert the ACTUAL migration in isolated PostgreSQL. No live payments.
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
end $roles$;
create table public.stadiums(id uuid primary key,owner_id uuid,name text);
create table public.teams(id uuid primary key,captain_id uuid);
create table public.bookings(
 id uuid primary key,stadium_id uuid,owner_id uuid,created_by_user_id uuid,
 payment_method text,status text,booking_type text,
 host_name text,player_team_name text,opponent_team_name text,
 stadium_name text,opponent_team_id uuid
);
create table public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid,
 title text,body text,message text,type text,is_read boolean,
 created_at timestamptz,booking_id uuid,metadata jsonb
);
-- ACTUAL_CASH_BOOKING_MIGRATION
insert into public.stadiums(id,owner_id,name) values
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000101','ملعب النيل');
insert into public.teams(id,captain_id) values
 ('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000102'),
 ('00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000103');

-- A challenge confirmed at creation: true owner + opposing captain only.
-- owner_id and stadium_name are deliberately forged in the booking row.
insert into public.bookings(
 id,stadium_id,owner_id,created_by_user_id,payment_method,status,
 booking_type,host_name,player_team_name,opponent_team_name,
 stadium_name,opponent_team_id
) values
 ('00000000-0000-0000-0000-000000001001',
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000999',
 '00000000-0000-0000-0000-000000000103',
 'cash','confirmed','challenge','الكابتن','النيل','الجزيرة',
 'ملعب مزيف','00000000-0000-0000-0000-000000000201');
do $created_confirmed$
begin
 if (select count(*) from public.notifications where booking_id='00000000-0000-0000-0000-000000001001')<>2
 or (select count(*) from public.notifications where booking_id='00000000-0000-0000-0000-000000001001'
       and user_id='00000000-0000-0000-0000-000000000101'
       and metadata->>'event'='cash_booking_confirmed')<>1
 or (select count(*) from public.notifications where booking_id='00000000-0000-0000-0000-000000001001'
       and user_id='00000000-0000-0000-0000-000000000102'
       and metadata->>'event'='cash_challenge_confirmed')<>1
 or exists(select 1 from public.notifications where booking_id='00000000-0000-0000-0000-000000001001'
       and (user_id='00000000-0000-0000-0000-000000000999'
        or body like '%ملعب مزيف%'))
 then raise exception 'CASH_OWNER_OR_CHALLENGE_RECIPIENT_MISROUTED';end if;
end $created_confirmed$;

-- Cash booking starts pending. Notification only when the authoritative
-- booking status is changed to confirmed, never on a repeated same status.
insert into public.bookings(id,stadium_id,owner_id,created_by_user_id,
 payment_method,status,booking_type,host_name)
values('00000000-0000-0000-0000-000000001002',
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000999',
 '00000000-0000-0000-0000-000000000104',
 'cash','pending','regular','محمود');
do $pending$ begin
 if exists(select 1 from public.notifications where booking_id='00000000-0000-0000-0000-000000001002')
 then raise exception 'PENDING_BOOKING_FALSIFY_CONFIRMED';end if;
end $pending$;
update public.bookings set status='confirmed'
 where id='00000000-0000-0000-0000-000000001002';
update public.bookings set status='confirmed'
 where id='00000000-0000-0000-0000-000000001002';
update public.bookings set status='cancelled'
 where id='00000000-0000-0000-0000-000000001002';
update public.bookings set status='confirmed'
 where id='00000000-0000-0000-0000-000000001002';
do $state_change$ begin
 if (select count(*) from public.notifications where booking_id='00000000-0000-0000-0000-000000001002')<>1
 or (select count(*) from public.notifications where booking_id='00000000-0000-0000-0000-000000001002'
       and user_id='00000000-0000-0000-0000-000000000101'
       and metadata->>'event'='cash_booking_confirmed')<>1
 then raise exception 'CASH_CONFIRMATION_UPDATE_NOT_IDEMPOTENT';end if;
end $state_change$;

-- No false payment success notification for card, no cancelled booking
-- confirmation, and no notification to a nonexistent venue owner.
insert into public.bookings(id,stadium_id,payment_method,status,booking_type)
values
 ('00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-000000000001','card','confirmed','regular'),
 ('00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000000001','cash','cancelled','regular'),
 ('00000000-0000-0000-0000-000000001005','00000000-0000-0000-0000-000000000999','cash','confirmed','regular');
update public.bookings set status='confirmed'
 where id='00000000-0000-0000-0000-000000001003';
-- Opponent captain equal to originator: only owner receives a booking notice.
insert into public.bookings(
 id,stadium_id,created_by_user_id,payment_method,status,booking_type,
 opponent_team_id,player_team_name,opponent_team_name
) values('00000000-0000-0000-0000-000000001006',
 '00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000103',
 'cash','confirmed','challenge',
 '00000000-0000-0000-0000-000000000202','النيل','النيل');
do $false_alerts$ begin
 if exists(select 1 from public.notifications where booking_id in (
   '00000000-0000-0000-0000-000000001003',
   '00000000-0000-0000-0000-000000001004',
   '00000000-0000-0000-0000-000000001005'))
 or (select count(*) from public.notifications where booking_id='00000000-0000-0000-0000-000000001006')<>1
 then raise exception 'FALSE_CASH_CONFIRMATION_NOTIFICATION';end if;
end $false_alerts$;

-- Historical in-app receipts lack event metadata: never duplicate after
-- a confirmed booking is resubmitted or transition replayed.
insert into public.bookings(id,stadium_id,payment_method,status,booking_type)
values('00000000-0000-0000-0000-000000001007',
 '00000000-0000-0000-0000-000000000001','cash','pending','regular');
insert into public.notifications(user_id,title,booking_id)
values('00000000-0000-0000-0000-000000000101','حجز جديد مستلم!',
       '00000000-0000-0000-0000-000000001007');
update public.bookings set status='confirmed'
where id='00000000-0000-0000-0000-000000001007';
do $legacy_dedup$ begin
 if (select count(*) from public.notifications where booking_id='00000000-0000-0000-0000-000000001007')<>1
 then raise exception 'OLD_RECEIPT_WAS_DUPLICATED';end if;
 if has_function_privilege('anon','public.notify_cash_booking_parties()','EXECUTE')
 or has_function_privilege('authenticated','public.notify_cash_booking_parties()','EXECUTE')
 then raise exception 'CASH_TRIGGER_DIRECT_EXECUTE_EXPOSED';end if;
 if (select count(*) from pg_trigger where tgrelid='public.bookings'::regclass
    and tgname='trg_notify_cash_booking_parties' and tgenabled='O')<>1
 then raise exception 'CASH_CONFIRMATION_TRIGGER_MISSING';end if;
end $legacy_dedup$;
