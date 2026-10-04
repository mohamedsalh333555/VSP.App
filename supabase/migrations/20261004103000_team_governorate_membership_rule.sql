-- Team governorate membership rule.
-- Captain governorate is the source of truth; cross-governorate team members are rejected.
-- Also removes the stale teams.city dependency from the team RPCs.

CREATE OR REPLACE FUNCTION public.enforce_team_member_governorate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_team_governorate text;
  v_captain_governorate text;
  v_player_governorate text;
BEGIN
  SELECT t.governorate, u.governorate
    INTO v_team_governorate, v_captain_governorate
  FROM public.teams t
  JOIN public.users u ON u.id = t.captain_id
  WHERE t.id = NEW.team_id;

  SELECT governorate INTO v_player_governorate
  FROM public.users
  WHERE id = NEW.user_id;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RAISE EXCEPTION 'TEAM_CAPTAIN_GOVERNORATE_REQUIRED';
  END IF;

  IF v_player_governorate IS NULL OR btrim(v_player_governorate) = '' THEN
    RAISE EXCEPTION 'PLAYER_GOVERNORATE_REQUIRED';
  END IF;

  IF lower(btrim(v_player_governorate)) <> lower(btrim(v_captain_governorate)) THEN
    RAISE EXCEPTION 'TEAM_GOVERNORATE_MISMATCH';
  END IF;

  IF v_team_governorate IS NULL
     OR btrim(v_team_governorate) = ''
     OR lower(btrim(v_team_governorate)) <> lower(btrim(v_captain_governorate)) THEN
    UPDATE public.teams
    SET governorate = v_captain_governorate, updated_at = now()
    WHERE id = NEW.team_id;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_team_member_governorate ON public.team_members;
CREATE TRIGGER trg_team_member_governorate
BEFORE INSERT OR UPDATE OF team_id, user_id
ON public.team_members
FOR EACH ROW
EXECUTE FUNCTION public.enforce_team_member_governorate();

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
    governorate, preferred_formation, elo_rating, points, wins, draws, losses,
    matches_played, current_winning_streak, championships_won, is_active,
    is_blocked, is_verified
  )
  VALUES(
    v_name, coalesce(p_data->>'bio', ''), v_caller, p_data->>'logo_url',
    coalesce(p_data->>'primary_color', '#FFFFFF'),
    coalesce(p_data->>'secondary_color', '#000000'),
    v_captain_governorate,
    coalesce(p_data->>'preferred_formation', '2-2-1'),
    1200, 0, 0, 0, 0, 0, 0, 0, true, false, false
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

CREATE OR REPLACE FUNCTION public.add_team_member_atomic(
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
  v_exists boolean;
  v_captain_governorate text;
  v_player_governorate text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id
      AND (captain_id = auth.uid()
           OR v_role IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  PERFORM 1 FROM public.teams WHERE id = p_team_id FOR UPDATE;

  SELECT u.governorate INTO v_captain_governorate
  FROM public.teams t
  JOIN public.users u ON u.id = t.captain_id
  WHERE t.id = p_team_id;

  SELECT governorate INTO v_player_governorate
  FROM public.users WHERE id = p_user_id;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'محافظة الكابتن غير محددة.'
    );
  END IF;

  IF v_player_governorate IS NULL OR btrim(v_player_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'PLAYER_GOVERNORATE_REQUIRED',
      'message', 'لا يمكن إضافة لاعب بدون محافظة محددة.'
    );
  END IF;

  IF lower(btrim(v_player_governorate)) <> lower(btrim(v_captain_governorate)) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'TEAM_GOVERNORATE_MISMATCH',
      'message', 'لا يمكن إضافة اللاعب لأن محافظته مختلفة عن محافظة كابتن الفريق.'
    );
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_user_id
  ) INTO v_exists;

  IF v_exists THEN
    RETURN jsonb_build_object('success', true, 'already_member', true);
  END IF;

  IF (SELECT count(*) FROM public.team_members WHERE team_id = p_team_id) >= 12 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team is full');
  END IF;

  IF (SELECT count(*) FROM public.team_members WHERE user_id = p_user_id) >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player reached maximum teams');
  END IF;

  INSERT INTO public.team_members(team_id, user_id)
  VALUES(p_team_id, p_user_id);

  RETURN jsonb_build_object('success', true);
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
      preferred_formation = coalesce(p_data->>'preferred_formation', preferred_formation),
      updated_at = now()
  WHERE id = p_team_id;

  RETURN jsonb_build_object('success', true);
END;
$function$;

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
      'success', false, 'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
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
$function$;
