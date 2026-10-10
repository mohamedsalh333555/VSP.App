-- Migration: Create teams_public view and secure get_team_invite_code RPC
-- Task 6 Phase A: Expose public team columns safely while securing captain_phone and active_invite_code

CREATE OR REPLACE VIEW public.teams_public AS
SELECT
  id,
  name,
  captain_id,
  logo_url,
  points,
  wins,
  draws,
  losses,
  matches_played,
  current_winning_streak,
  championships_won,
  created_at,
  updated_at,
  last_reset_year,
  primary_color,
  secondary_color,
  captain_image_url,
  beaten_opponents,
  played_opponents,
  unlocked_badges,
  governorate,
  sport_type,
  price_per_person,
  date,
  stadium,
  captain_name,
  is_official,
  attendance_score,
  verified_badge,
  has_1v1_champion,
  bio
FROM public.teams;

GRANT SELECT ON public.teams_public TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_team_invite_code(p_team_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_team record;
  v_is_admin boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT id, captain_id, active_invite_code, invite_code_expires_at
  INTO v_team
  FROM public.teams
  WHERE id = p_team_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'الفريق غير موجود');
  END IF;

  v_is_admin := false;
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE id = v_caller_id
      AND role IN ('admin', 'super_admin', 'co_founder', 'cofounder')
  ) THEN
    v_is_admin := true;
  END IF;

  IF (v_team.captain_id IS DISTINCT FROM v_caller_id) AND (NOT v_is_admin) THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح لك بالاطلاع على كود الدعوة');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'team_id', v_team.id,
    'invite_code', v_team.active_invite_code,
    'expires_at', v_team.invite_code_expires_at
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_team_invite_code(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_team_invite_code(uuid) TO authenticated;
