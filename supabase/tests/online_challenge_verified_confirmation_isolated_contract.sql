-- Actual migration on throwaway SQL. No real webhook, no remote database.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
END $roles$;
CREATE SCHEMA vsp_notifications_private;
CREATE TABLE public.teams(id uuid PRIMARY KEY,captain_id uuid,name text);
CREATE TABLE public.stadiums(id uuid PRIMARY KEY,name text);
CREATE TABLE public.bookings(
 id uuid PRIMARY KEY,user_id uuid,booking_type text,challenge_status text,
 payment_method text,status text,webhook_verified boolean,
 paymob_txn_id text,paymob_order_id text,payment_status text,
 payment_reconcile_state text,player_team_id uuid,opponent_team_id uuid,
 stadium_id uuid);
CREATE TABLE public.transactions(
 id uuid PRIMARY KEY,booking_id uuid,user_id uuid,paymob_transaction_id text,
 type text,status text,payment_method text,amount numeric,gross_amount numeric,
 metadata jsonb,created_at timestamptz DEFAULT now());
CREATE TABLE public.webhook_logs(
 provider text,event_type text,status text,signature_verified boolean,
 booking_id uuid,txn_id text,order_id text,payload jsonb);
CREATE TABLE public.notifications(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid,title text,
 body text,message text,type text,is_read boolean,booking_id uuid,
 created_at timestamptz,metadata jsonb);
-- ACTUAL_VERIFIED_CHALLENGE_NOTICE_MIGRATION
INSERT INTO public.stadiums(id,name) VALUES
 ('00000000-0000-0000-0000-000000000001','ملعب النيل');
INSERT INTO public.teams(id,captain_id,name) VALUES
 ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000201','الزمالك'),
 ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000202','أسوان');
INSERT INTO public.bookings(
 id,user_id,booking_type,challenge_status,payment_method,status,
 webhook_verified,paymob_txn_id,paymob_order_id,payment_status,
 payment_reconcile_state,player_team_id,opponent_team_id,stadium_id)
VALUES
 ('00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000201',
  'challenge','ready','card','pending',false,null,null,
  'pending','unpaid',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000001002',
  '00000000-0000-0000-0000-000000000201',
  'challenge','ready','wallet','pending',false,null,null,
  'pending','unpaid',
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000001');
-- A cancelled pending match (aborted payment) has no live match notice.
UPDATE public.bookings SET status='cancelled'
 WHERE id='00000000-0000-0000-0000-000000001002';
DO $no_pending$ BEGIN
 IF EXISTS(SELECT 1 FROM public.notifications)
 THEN RAISE EXCEPTION 'NOTIFIED_PENDING_OR_CANCELLED_CHALLENGE';END IF;
END $no_pending$;
INSERT INTO public.transactions(
 id,booking_id,user_id,paymob_transaction_id,type,status,payment_method,
 amount,gross_amount,metadata)
VALUES('00000000-0000-0000-0000-000000002001',
 '00000000-0000-0000-0000-000000001001',
 '00000000-0000-0000-0000-000000000201','929292',
 'deposit','completed','card',50,55,
 '{"paymob_order_id":"orderABC"}');
-- Do not accept booking flags alone or an unsigned/mismatched webhook.
INSERT INTO public.webhook_logs(
 provider,event_type,status,signature_verified,booking_id,txn_id,order_id,payload)
VALUES('paymob','transaction_response','success',false,
 '00000000-0000-0000-0000-000000001001','929292','orderABC',
 '{"success":true,"pending":false,"amount_cents":5500}');
UPDATE public.bookings SET status='confirmed',
 challenge_status='confirmed',webhook_verified=true,
 paymob_txn_id='929292',paymob_order_id='orderABC',
 payment_status='partially_paid',payment_reconcile_state='partially_paid'
WHERE id='00000000-0000-0000-0000-000000001001';
DO $no_unsigned$ BEGIN
 IF EXISTS(SELECT 1 FROM public.notifications)
 THEN RAISE EXCEPTION 'UNVERIFIED_CHALLENGE_CONFIRMED';END IF;
END $no_unsigned$;
-- Reset fixture, then deliver a signed+matching callback before transition.
UPDATE public.bookings SET status='pending',challenge_status='ready'
WHERE id='00000000-0000-0000-0000-000000001001';
INSERT INTO public.webhook_logs(
 provider,event_type,status,signature_verified,booking_id,txn_id,order_id,payload)
VALUES('paymob','transaction_response','success',true,
 '00000000-0000-0000-0000-000000001001','929292','orderABC',
 '{"success":true,"pending":false,"amount_cents":5500}');
UPDATE public.bookings SET status='confirmed',challenge_status='confirmed'
WHERE id='00000000-0000-0000-0000-000000001001';
UPDATE public.bookings SET status='confirmed'
WHERE id='00000000-0000-0000-0000-000000001001';
DO $confirmed$ BEGIN
 IF (SELECT count(*) FROM public.notifications)<>2
 OR (SELECT count(*) FROM public.notifications
     WHERE user_id='00000000-0000-0000-0000-000000000201'
       AND booking_id='00000000-0000-0000-0000-000000001001'
       AND type='booking_confirmed'
       AND metadata->>'event'='verified_online_challenge_confirmed')<>1
 OR (SELECT count(*) FROM public.notifications
     WHERE user_id='00000000-0000-0000-0000-000000000202'
       AND metadata->>'event'='verified_online_challenge_confirmed')<>1
 OR EXISTS(SELECT 1 FROM public.notifications
     WHERE user_id NOT IN (
        '00000000-0000-0000-0000-000000000201',
        '00000000-0000-0000-0000-000000000202'))
 THEN RAISE EXCEPTION 'CHALLENGE_CONFIRMATION_RECIPIENT_WRONG_OR_DUP';END IF;
 IF has_function_privilege('anon',
   'vsp_notifications_private.notify_verified_online_challenge()','EXECUTE')
 OR has_function_privilege('authenticated',
   'vsp_notifications_private.notify_verified_online_challenge()','EXECUTE')
 THEN RAISE EXCEPTION 'PUBLIC_CHALLENGE_NOTIFY_EXECUTION';END IF;
END $confirmed$;
