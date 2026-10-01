-- Migration: 20261001260000_team_journey_ssot.sql
-- Description: Team Journey SSOT - Schema and State Machine hardening
--   1. Fix remove_team_member_atomic (replace non-existent 'id' column with joined_at ASC).
--   2. Allow self-leave (member can voluntarily leave team).
--   3. Handle sole captain leave (safely delete empty team if last member leaves).
--   4. Add explicit atomic captain transfer: transfer_team_captaincy_atomic.
--   5. Security grants and revokes.

-- 1. FIX remove_team_member_atomic
CREATE OR REPLACE FUNCTION public.remove_team_member_atomic(
  p_team_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_cap uuid;
  v_next uuid;
  v_team_disbanded boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  SELECT captain_id INTO v_cap FROM public.teams WHERE id = p_team_id FOR UPDATE;

  IF v_cap IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team not found');
  END IF;

  -- Authority Check: Caller must be the member leaving (self-leave), the team captain, or platform admin
  IF auth.uid() <> p_user_id AND v_cap <> auth.uid() AND COALESCE(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: فقط الكابتن أو العضو نفسه يمكنه إتمام المغادرة.');
  END IF;

  -- Active match or ongoing tournament safeguard
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

  -- Verify user is actually a member of this team
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player is not a member of this team');
  END IF;

  -- Delete member record
  DELETE FROM public.team_members
  WHERE team_id = p_team_id AND user_id = p_user_id;

  -- If the captain is removing themselves / leaving:
  IF v_cap = p_user_id THEN
    -- Find the next oldest joined member (Primary Key is (team_id, user_id), ordering by joined_at ASC)
    SELECT user_id INTO v_next
    FROM public.team_members
    WHERE team_id = p_team_id
    ORDER BY joined_at ASC
    LIMIT 1;

    IF v_next IS NOT NULL THEN
      -- Transfer captaincy to next senior member
      UPDATE public.teams t
      SET captain_id = v_next,
          captain_name = u.name,
          captain_phone = u.phone,
          captain_image_url = u.profile_image_url,
          updated_at = now()
      FROM public.users u
      WHERE t.id = p_team_id AND u.id = v_next;
    ELSE
      -- Team has 0 remaining members: delete empty team cleanly
      DELETE FROM public.teams WHERE id = p_team_id;
      v_team_disbanded := true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'captain_transferred', (v_cap = p_user_id AND v_next IS NOT NULL),
    'new_captain_id', v_next,
    'team_disbanded', v_team_disbanded
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.remove_team_member_atomic(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.remove_team_member_atomic(uuid, uuid) TO authenticated, service_role;


-- 2. CREATE EXPLICIT transfer_team_captaincy_atomic
CREATE OR REPLACE FUNCTION public.transfer_team_captaincy_atomic(
  p_team_id uuid,
  p_new_captain_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_cap uuid;
  v_new_user record;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  SELECT * INTO v_cap FROM public.teams WHERE id = p_team_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'الفريق غير موجود.');
  END IF;

  -- Only current captain or platform admin can transfer captaincy
  IF v_cap <> auth.uid() AND COALESCE(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: نقل شارة الكابتنة من صلاحية الكابتن الحالي فقط.');
  END IF;

  IF p_new_captain_id = auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'أنت بالفعل كابتن هذا الفريق.');
  END IF;

  -- Target must be an active registered member of this team
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_new_captain_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'اللاعب المحدد ليس عضواً في هذا الفريق.');
  END IF;

  -- Target cannot be blocked
  SELECT * INTO v_new_user FROM public.users WHERE id = p_new_captain_id;
  IF NOT FOUND OR COALESCE(v_new_user.is_blocked, false) = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'حساب اللاعب المحدد غير متاح أو محظور.');
  END IF;

  -- Active match or ongoing tournament safeguard
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

  -- Atomically update captain in teams table
  UPDATE public.teams
  SET captain_id = p_new_captain_id,
      captain_name = COALESCE(v_new_user.name, 'Captain'),
      captain_phone = COALESCE(v_new_user.phone, ''),
      captain_image_url = COALESCE(v_new_user.profile_image_url, ''),
      updated_at = v_now
  WHERE id = p_team_id;

  -- Notify the new captain
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
$function$;

REVOKE ALL ON FUNCTION public.transfer_team_captaincy_atomic(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transfer_team_captaincy_atomic(uuid, uuid) TO authenticated, service_role;

-- Record migration in schema_migrations
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261001260000', 'team_journey_ssot')
ON CONFLICT (version) DO NOTHING;
