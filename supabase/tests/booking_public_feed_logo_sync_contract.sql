-- Disposable PostgreSQL contract for the exact staging public-feed function.
-- This fixture contains only synthetic rows and runs inside a transaction.
CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE public.bookings(
 id uuid PRIMARY KEY,
 stadium_id uuid, stadium_name text, stadium_image_url text,
 start_time timestamptz, end_time timestamptz, operational_date date,
 booking_type text NOT NULL DEFAULT 'challenge',
 player_team_id uuid, player_team_name text, player_team_logo_url text,
 host_name text, host_avatar_url text,
 opponent_team_id uuid, opponent_team_name text,
 opponent_team_logo_url text,
 is_private boolean NOT NULL DEFAULT false, rent_ball boolean DEFAULT false,
 total_price numeric DEFAULT 0, currency text DEFAULT 'EGP',
 status text NOT NULL DEFAULT 'confirmed', match_result_status text DEFAULT 'noResult',
 home_score int, away_score int, final_outcome text,
 current_players int, max_players int, total_field_capacity int,
 matchup_mode text, matchup_closed_at timestamptz,
 created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(),
 payment_status text DEFAULT 'pending', platform_fee numeric DEFAULT 0,
 gateway_fee numeric DEFAULT 0, vsp_commission numeric DEFAULT 0
);
CREATE TABLE public.booking_public_feed(
 id uuid PRIMARY KEY,
 stadium_id uuid, stadium_name text, stadium_image_url text,
 start_time timestamptz, end_time timestamptz, operational_date date,
 booking_type text, player_team_id uuid, player_team_name text,
 player_team_logo_url text, host_name text, host_avatar_url text,
 opponent_team_id uuid, opponent_team_name text, opponent_team_logo_url text,
 is_private boolean, rent_ball boolean, total_price numeric, currency text,
 status text, match_result_status text, home_score int, away_score int,
 final_outcome text, current_players int, players_per_team int,
 total_field_capacity int, matchup_mode text,
 matchup_closed_at timestamptz, created_at timestamptz, updated_at timestamptz
);

-- INSTALL_FEED_LOGO_SYNC_FIX

CREATE TRIGGER trg_sync_booking_public_feed
 AFTER INSERT OR DELETE OR UPDATE ON public.bookings
 FOR EACH ROW EXECUTE FUNCTION public.sync_booking_public_feed();

INSERT INTO public.bookings(
 id,stadium_name,booking_type,opponent_team_logo_url,is_private,
 status,payment_status,platform_fee,gateway_fee,vsp_commission,max_players)
VALUES
 ('00000000-0000-0000-0000-000000000301','Synthetic pitch',
 'challenge','logo-original.png',false,'confirmed','pending',12,3,7,5);

DO $check_initial$
BEGIN
 IF (SELECT opponent_team_logo_url FROM public.booking_public_feed
      WHERE id='00000000-0000-0000-0000-000000000301')
     IS DISTINCT FROM 'logo-original.png' THEN
   RAISE EXCEPTION 'Public match INSERT did not sync opponent logo'; END IF;
 IF (SELECT players_per_team FROM public.booking_public_feed
      WHERE id='00000000-0000-0000-0000-000000000301')<>5 THEN
   RAISE EXCEPTION 'Public match capacity value was not mapped'; END IF;
END;
$check_initial$;

UPDATE public.bookings SET
 opponent_team_logo_url='logo-updated.png',status='completed'
WHERE id='00000000-0000-0000-0000-000000000301';

DO $check_update$
BEGIN
 IF (SELECT opponent_team_logo_url FROM public.booking_public_feed
      WHERE id='00000000-0000-0000-0000-000000000301')
     IS DISTINCT FROM 'logo-updated.png' THEN
   RAISE EXCEPTION 'Public match UPDATE did not sync opponent logo'; END IF;
 IF (SELECT status FROM public.booking_public_feed
      WHERE id='00000000-0000-0000-0000-000000000301')
     IS DISTINCT FROM 'completed' THEN
   RAISE EXCEPTION 'Public match UPDATE did not sync status'; END IF;
 IF (SELECT ROW(platform_fee,gateway_fee,vsp_commission)
      FROM public.bookings WHERE id='00000000-0000-0000-0000-000000000301')
     IS DISTINCT FROM ROW(12::numeric,3::numeric,7::numeric) THEN
   RAISE EXCEPTION 'Feed synchronization modified payment fields'; END IF;
END;
$check_update$;

-- Private, cancelled, and open_join must never remain in the public feed.
UPDATE public.bookings SET is_private=true
 WHERE id='00000000-0000-0000-0000-000000000301';
DO $check_private$
BEGIN
 IF EXISTS(SELECT 1 FROM public.booking_public_feed
   WHERE id='00000000-0000-0000-0000-000000000301') THEN
   RAISE EXCEPTION 'Private booking leaked into public feed'; END IF;
END;
$check_private$;

UPDATE public.bookings SET is_private=false, status='cancelled'
 WHERE id='00000000-0000-0000-0000-000000000301';
DO $check_cancelled$
BEGIN
 IF EXISTS(SELECT 1 FROM public.booking_public_feed
   WHERE id='00000000-0000-0000-0000-000000000301') THEN
   RAISE EXCEPTION 'Cancelled booking leaked into public feed'; END IF;
END;
$check_cancelled$;

UPDATE public.bookings SET status='confirmed',booking_type='open_join'
 WHERE id='00000000-0000-0000-0000-000000000301';
DO $check_pickup$
BEGIN
 IF EXISTS(SELECT 1 FROM public.booking_public_feed
   WHERE id='00000000-0000-0000-0000-000000000301') THEN
   RAISE EXCEPTION 'open_join booking leaked into public feed'; END IF;
END;
$check_pickup$;

UPDATE public.bookings SET booking_type='challenge',
 opponent_team_logo_url='logo-republished.png'
 WHERE id='00000000-0000-0000-0000-000000000301';
DO $check_republished$
BEGIN
 IF (SELECT opponent_team_logo_url FROM public.booking_public_feed
   WHERE id='00000000-0000-0000-0000-000000000301')
   IS DISTINCT FROM 'logo-republished.png' THEN
   RAISE EXCEPTION 'Eligible booking was not republished'; END IF;
END;
$check_republished$;

DELETE FROM public.bookings
 WHERE id='00000000-0000-0000-0000-000000000301';
DO $check_delete$
BEGIN
 IF EXISTS(SELECT 1 FROM public.booking_public_feed
   WHERE id='00000000-0000-0000-0000-000000000301') THEN
   RAISE EXCEPTION 'Deleted booking was left in public feed'; END IF;
END;
$check_delete$;
