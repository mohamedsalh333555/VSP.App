-- VSP isolated test: exact public.transfer_team_captaincy_atomic from
-- production AND staging on 2026-11-17 (same prosrc sha256 below).
-- hash: 10666ad8336552ec294e02d937226d67d2232e5e8a8689ca11277b994915e5ac
-- Fixture is NOT a migration; never execute against hosted user data.
SET client_min_messages = warning;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $uid$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$uid$;
CREATE TABLE public.users(
  id uuid PRIMARY KEY, name text, phone text, profile_image_url text,
  governorate text, role text DEFAULT 'player', is_blocked boolean DEFAULT false
);
CREATE TABLE public.teams(
  id uuid PRIMARY KEY, captain_id uuid NOT NULL,
  captain_name text, captain_phone text, captain_image_url text,
  governorate text, updated_at timestamptz
);
CREATE TABLE public.team_members(team_id uuid NOT NULL, user_id uuid NOT NULL,
  PRIMARY KEY(team_id,user_id));
CREATE TABLE public.bookings(
  status text, player_team_id uuid, opponent_team_id uuid, end_time timestamptz
);
CREATE TABLE public.championships(status text, joined_teams uuid[]);
CREATE TABLE public.notifications(
  user_id uuid, title text, body text, type text, created_at timestamptz
);

CREATE OR REPLACE FUNCTION public.transfer_team_captaincy_atomic(p_team_id uuid, p_new_captain_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_cap uuid;
  v_current_captain_governorate text;
  v_new_captain_governorate text;
  v_new_user record;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  SELECT captain_id INTO v_cap FROM public.teams WHERE id = p_team_id FOR UPDATE;

  IF v_cap IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'الفريق غير موجود.');
  END IF;

  IF v_cap <> auth.uid()
     AND COALESCE(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: نقل شارة الكابتنة من صلاحية الكابتن الحالي فقط.');
  END IF;

  IF p_new_captain_id = auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'أنت بالفعل كابتن هذا الفريق.');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_new_captain_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'اللاعب المحدد ليس عضواً في هذا الفريق.');
  END IF;

  SELECT * INTO v_new_user FROM public.users WHERE id = p_new_captain_id;
  IF NOT FOUND OR COALESCE(v_new_user.is_blocked, false) = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'حساب اللاعب المحدد غير متاح أو محظور.');
  END IF;

  SELECT governorate INTO v_current_captain_governorate
  FROM public.users WHERE id = v_cap;

  v_new_captain_governorate := v_new_user.governorate;

  IF v_current_captain_governorate IS NULL OR btrim(v_current_captain_governorate) = ''
     OR v_new_captain_governorate IS NULL OR btrim(v_new_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'لا يمكن نقل الكابتنة بدون محافظة محددة.'
    );
  END IF;

  IF lower(btrim(v_current_captain_governorate)) <> lower(btrim(v_new_captain_governorate)) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_MISMATCH',
      'message', 'لا يمكن نقل الكابتنة إلى لاعب من محافظة مختلفة عن محافظة الفريق.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE status = 'confirmed'
      AND (player_team_id = p_team_id OR opponent_team_id = p_team_id)
      AND end_time > now()
  ) OR EXISTS (
    SELECT 1 FROM public.championships
    WHERE status IN ('open', 'ongoing')
      AND p_team_id = ANY(COALESCE(joined_teams, ARRAY[]::uuid[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'active_match_or_tournament_error');
  END IF;

  UPDATE public.teams
  SET captain_id = p_new_captain_id,
      captain_name = COALESCE(v_new_user.name, 'Captain'),
      captain_phone = COALESCE(v_new_user.phone, ''),
      captain_image_url = COALESCE(v_new_user.profile_image_url, ''),
      governorate = v_new_captain_governorate,
      updated_at = v_now
  WHERE id = p_team_id;

  INSERT INTO public.notifications (user_id, title, body, type, created_at)
  VALUES (
    p_new_captain_id,
    'شارة الكابتنة ⚽',
    'تم نقل شارة قيادة الفريق إليك رسمياً. يمكنك الآن إدارة الفريق وقائمة اللاعبين.',
    'team_transfer',
    v_now
  );

  RETURN jsonb_build_object(
    'success', true,
    'team_id', p_team_id,
    'new_captain_id', p_new_captain_id,
    'new_captain_name', v_new_user.name
  );
END;
$function$
;

INSERT INTO public.users(id,name,governorate,phone) VALUES
('00000000-0000-4000-8000-000000000001','Old captain','القاهرة','01000000001'),
('00000000-0000-4000-8000-000000000002','New captain','القاهرة','01000000002'),
('00000000-0000-4000-8000-000000000003','Third captain','القاهرة','01000000003'),
('00000000-0000-4000-8000-000000000004','Outsider','القاهرة','01000000004');
INSERT INTO public.teams(id,captain_id,captain_name,governorate) VALUES
('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000001','Old captain','القاهرة');
INSERT INTO public.team_members(team_id,user_id) VALUES
('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002'),('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000003');

-- Assertions use a real copy of the installed function, never a reimplementation.
DO $test$
DECLARE r jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','',true);
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Unauthenticated transfer accepted'; END IF;

  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Outsider transfer accepted'; END IF;

  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000004');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Nonmember captain accepted'; END IF;

  UPDATE public.users SET is_blocked=true WHERE id='00000000-0000-4000-8000-000000000002';
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Blocked member accepted'; END IF;
  UPDATE public.users SET is_blocked=false WHERE id='00000000-0000-4000-8000-000000000002';

  UPDATE public.users SET governorate='الإسكندرية' WHERE id='00000000-0000-4000-8000-000000000002';
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Cross-region captain accepted'; END IF;
  UPDATE public.users SET governorate='القاهرة' WHERE id='00000000-0000-4000-8000-000000000002';

  INSERT INTO public.bookings(status,player_team_id,end_time)
  VALUES('confirmed','00000000-0000-4000-8000-000000000010',now()+interval '1 day');
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Active booking transfer accepted'; END IF;
  DELETE FROM public.bookings;

  INSERT INTO public.championships(status,joined_teams)
  VALUES('ongoing',ARRAY['00000000-0000-4000-8000-000000000010'::uuid]);
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Active league transfer accepted'; END IF;
  DELETE FROM public.championships;

  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002');
  IF r->>'success' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Valid captain transfer rejected: %',r; END IF;
  IF (SELECT captain_id FROM public.teams WHERE id='00000000-0000-4000-8000-000000000010') <> '00000000-0000-4000-8000-000000000002'::uuid
     THEN RAISE EXCEPTION 'Captain field not changed'; END IF;
  IF (SELECT count(*) FROM public.notifications WHERE type='team_transfer') <> 1
     THEN RAISE EXCEPTION 'Transfer did not notify exactly one captain'; END IF;

  -- Old captain cannot overwrite the new captain, even though still a member.
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000003');
  IF r->>'success' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Former captain can transfer again'; END IF;

  -- New captain may transfer onward; one authoritative captain_id is retained.
  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
  r:=public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000003');
  IF r->>'success' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'New captain cannot transfer: %',r; END IF;
  IF (SELECT captain_id FROM public.teams WHERE id='00000000-0000-4000-8000-000000000010') <> '00000000-0000-4000-8000-000000000003'::uuid
     THEN RAISE EXCEPTION 'Team lost sole captain'; END IF;
  IF (SELECT count(*) FROM public.notifications WHERE type='team_transfer') <> 2
     THEN RAISE EXCEPTION 'Transfer notices are inconsistent'; END IF;
END;
$test$;

-- Reset the synthetic fixture for the two-session concurrency test.
UPDATE public.teams SET captain_id='00000000-0000-4000-8000-000000000001',captain_name='Old captain' WHERE id='00000000-0000-4000-8000-000000000010';
DELETE FROM public.notifications;
SELECT 'PASS: captain transfer authorization, blocked, region, active games, sole successor' AS verdict;
