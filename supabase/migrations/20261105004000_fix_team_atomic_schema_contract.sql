-- Align the team RPCs with the actual public.teams schema.
-- The previous definitions referenced preferred_formation, elo_rating,
-- is_active, is_blocked and is_verified, none of which exist on teams.

CREATE OR REPLACE FUNCTION public.create_team_atomic(
  p_data jsonb,
  p_member_uids uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_team_id uuid;
  v_caller uuid := auth.uid();
  v_count int;
  v_name text;
  v_captain_governorate text;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  v_count := coalesce(array_length(p_member_uids, 1), 0);
  v_name := trim(coalesce(p_data->>'name', ''));

  IF v_count < 1 OR v_count > 12 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team members must be between 1 and 12');
  END IF;

  IF cardinality(ARRAY(SELECT DISTINCT x FROM unnest(p_member_uids) x)) <> v_count THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duplicate team member');
  END IF;

  IF p_member_uids[1] <> v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only the captain can create the team');
  END IF;

  IF v_name = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team name is required');
  END IF;

  SELECT governorate INTO v_captain_governorate
  FROM public.users WHERE id = v_caller;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'يجب تحديد محافظة الكابتن قبل إنشاء الفريق.'
    );
  END IF;

  IF (SELECT count(*) FROM public.users WHERE id = ANY(p_member_uids)) <> v_count THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_TEAM_MEMBER',
      'message', 'أحد اللاعبين غير موجود في النظام.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = ANY(p_member_uids)
      AND (
        u.governorate IS NULL OR btrim(u.governorate) = ''
        OR lower(btrim(u.governorate)) <> lower(btrim(v_captain_governorate))
      )
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'TEAM_GOVERNORATE_MISMATCH',
      'message', 'لا يمكن إنشاء الفريق لأن جميع اللاعبين يجب أن يكونوا من نفس محافظة الكابتن.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.teams
    WHERE lower(trim(name)) = lower(v_name)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team name already exists');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.team_members
    WHERE user_id = ANY(p_member_uids)
    GROUP BY user_id
    HAVING count(*) >= 3
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'A player has reached the maximum of 3 teams');
  END IF;

  INSERT INTO public.teams(
    name, bio, captain_id, logo_url, primary_color, secondary_color,
    governorate, points, wins, draws, losses, matches_played,
    current_winning_streak, championships_won, is_official
  )
  VALUES(
    v_name, coalesce(p_data->>'bio', ''), v_caller, p_data->>'logo_url',
    coalesce(p_data->>'primary_color', '#FFFFFF'),
    coalesce(p_data->>'secondary_color', '#000000'),
    v_captain_governorate,
    0, 0, 0, 0, 0, 0, 0, false
  )
  RETURNING id INTO v_team_id;

  INSERT INTO public.team_members(team_id, user_id)
  SELECT v_team_id, x FROM unnest(p_member_uids) x;

  RETURN jsonb_build_object(
    'success', true,
    'team_id', v_team_id,
    'governorate', v_captain_governorate
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_team_atomic(
  p_team_id uuid,
  p_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_captain_governorate text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id
      AND (captain_id = auth.uid()
           OR coalesce(v_role, '') IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT u.governorate INTO v_captain_governorate
  FROM public.teams t
  JOIN public.users u ON u.id = t.captain_id
  WHERE t.id = p_team_id;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'محافظة الكابتن غير محددة.'
    );
  END IF;

  UPDATE public.teams
  SET name = coalesce(p_data->>'name', name),
      bio = coalesce(p_data->>'bio', bio),
      logo_url = coalesce(p_data->>'logo_url', logo_url),
      primary_color = coalesce(p_data->>'primary_color', primary_color),
      secondary_color = coalesce(p_data->>'secondary_color', secondary_color),
      governorate = v_captain_governorate,
      updated_at = now()
  WHERE id = p_team_id;

  RETURN jsonb_build_object('success', true);
END;
$function$;
