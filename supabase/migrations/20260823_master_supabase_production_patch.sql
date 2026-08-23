-- ==============================================================================
-- 🏆 VSP SPORTS PLATFORM — SUPABASE MASTER PRODUCTION ENGINE & SECURITY PATCH
-- File: supabase/migrations/20260823_master_supabase_production_patch.sql
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة وقواعد تصنيف الـ ELO التلقائي عند انتهاء مباريات التحدي (Safe ELO Trigger)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    home_elo INT;
    away_elo INT;
    new_home_elo INT;
    new_away_elo INT;
    outcome FLOAT;
BEGIN
    IF NEW.status = 'confirmed' 
       AND NEW.booking_type = 'challenge' 
       AND NEW.final_outcome IS NOT NULL 
       AND COALESCE(NEW.elo_processed, false) = false THEN
        
        SELECT COALESCE(points, 1000) INTO home_elo FROM public.teams WHERE id = NEW.player_team_id;
        SELECT COALESCE(points, 1000) INTO away_elo FROM public.teams WHERE id = NEW.opponent_team_id;

        IF home_elo IS NOT NULL AND away_elo IS NOT NULL THEN
            IF NEW.final_outcome = 'homeWin' THEN outcome := 1.0;
            ELSIF NEW.final_outcome = 'draw' THEN outcome := 0.5;
            ELSE outcome := 0.0;
            END IF;

            new_home_elo := round(home_elo + 32 * (outcome - (1.0 / (1.0 + power(10, (away_elo - home_elo)::float / 400.0)))));
            new_away_elo := round(away_elo + 32 * ((1.0 - outcome) - (1.0 / (1.0 + power(10, (home_elo - away_elo)::float / 400.0)))));

            UPDATE public.teams 
            SET points = GREATEST(0, new_home_elo), 
                matches_played = COALESCE(matches_played, 0) + 1,
                wins = COALESCE(wins, 0) + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                draws = COALESCE(draws, 0) + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = COALESCE(losses, 0) + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.player_team_id;

            UPDATE public.teams 
            SET points = GREATEST(0, new_away_elo), 
                matches_played = COALESCE(matches_played, 0) + 1,
                wins = COALESCE(wins, 0) + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                draws = COALESCE(draws, 0) + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = COALESCE(losses, 0) + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.opponent_team_id;

            NEW.elo_processed := true;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calculate_elo ON public.bookings;
CREATE TRIGGER trg_calculate_elo
BEFORE UPDATE OF status, final_outcome ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.calculate_elo_on_match_completion();


-- ------------------------------------------------------------------------------
-- 2️⃣ حماية المعاملات المالية للحجوزات (Protect Booking Financial Fields)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_booking_sensitive_fields()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- منع التلاعب المباشر بحالة الدفع من العميل
  IF NEW.is_paid IS DISTINCT FROM OLD.is_paid AND NEW.is_paid = true AND OLD.is_paid = false THEN
    RAISE EXCEPTION 'Security Alert: Direct payment state manipulation is prohibited.';
  END IF;

  IF NEW.payment_status IS DISTINCT FROM OLD.payment_status AND NEW.payment_status = 'paid' AND OLD.payment_status != 'paid' THEN
    RAISE EXCEPTION 'Security Alert: Setting payment_status to paid directly is prohibited.';
  END IF;

  IF NEW.total_price IS DISTINCT FROM OLD.total_price THEN
    RAISE EXCEPTION 'Security Alert: Booking total_price cannot be modified directly.';
  END IF;

  IF NEW.deposit_paid IS DISTINCT FROM OLD.deposit_paid THEN
    RAISE EXCEPTION 'Security Alert: Booking deposit_paid cannot be modified directly.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_booking_sensitive_fields ON public.bookings;
CREATE TRIGGER trg_protect_booking_sensitive_fields
BEFORE UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.protect_booking_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 3️⃣ حماية وتأمين رتب المستخدمين ومنع التصعيد الذاتي (User Role & Security Guard)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(p_role text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_current_role text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF p_role NOT IN ('player', 'owner') THEN
    RAISE EXCEPTION 'Invalid role assignment attempt (%s). Only player or owner allowed.', p_role;
  END IF;

  SELECT role INTO v_current_role FROM public.users WHERE id = v_uid;

  IF v_current_role IN ('admin', 'co_founder') THEN
    RETURN true;
  END IF;

  UPDATE public.users
  SET role = p_role, updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Security Alert: Modifying user role directly is prohibited.';
  END IF;

  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
    RAISE EXCEPTION 'Security Alert: Modifying is_blocked status directly is prohibited.';
  END IF;

  IF NEW.verification_status IS DISTINCT FROM OLD.verification_status AND NEW.verification_status IN ('approved', 'verified') THEN
    RAISE EXCEPTION 'Security Alert: Self-approving verification status is prohibited.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_user_sensitive_fields
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.protect_user_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 4️⃣ حماية بطولات المالك من الاعتماد الذاتي غير المصرح به (Championships Guard)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_championship_sensitive_fields()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  IF NEW.is_approved IS DISTINCT FROM OLD.is_approved AND NEW.is_approved = true THEN
    RAISE EXCEPTION 'Security Alert: Championship approval requires admin verification.';
  END IF;

  IF NEW.champion_team_id IS DISTINCT FROM OLD.champion_team_id AND NEW.champion_team_id IS NOT NULL THEN
    RAISE EXCEPTION 'Security Alert: Crowning tournament champion must be performed via tournament engine.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_championship_sensitive_fields ON public.championships;
CREATE TRIGGER trg_protect_championship_sensitive_fields
BEFORE UPDATE ON public.championships
FOR EACH ROW
EXECUTE FUNCTION public.protect_championship_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 5️⃣ دالة الانضمام الذرية للبطولات (Join Championship Atomic RPC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_championship_atomic(
    p_championship_id UUID,
    p_team_id UUID,
    p_player_ids UUID[],
    p_guest_names TEXT[],
    p_is_paid BOOLEAN,
    p_total_paid_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_joined_count INT;
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship not found');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship registration is closed');
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team not found');
    END IF;

    IF p_team_id = ANY(v_champ.joined_teams) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Team is already registered in this championship');
    END IF;

    v_joined_count := array_length(v_champ.joined_teams, 1);
    IF v_joined_count IS NULL THEN v_joined_count := 0; END IF;

    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'Championship is already full');
    END IF;

    -- إضافة الفريق لقائمة الفرق المنضمة
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), p_team_id),
        paid_teams = CASE 
            WHEN p_is_paid THEN array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), p_team_id)
            ELSE paid_teams 
        END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    -- حفظ تشكيلة الفريق في جدول tournament_rosters
    INSERT INTO public.tournament_rosters (
        championship_id,
        team_id,
        player_ids,
        guest_names,
        is_paid,
        paid_amount,
        created_at,
        updated_at
    ) VALUES (
        p_championship_id,
        p_team_id,
        p_player_ids,
        p_guest_names,
        p_is_paid,
        COALESCE(p_total_paid_amount, 0),
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    )
    ON CONFLICT (championship_id, team_id) 
    DO UPDATE SET 
        player_ids = EXCLUDED.player_ids,
        guest_names = EXCLUDED.guest_names,
        is_paid = EXCLUDED.is_paid,
        paid_amount = EXCLUDED.paid_amount,
        updated_at = timezone('utc'::text, now());

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Team registered successfully in championship',
        'joined_teams_count', v_joined_count + 1
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 6️⃣ فهارس الأداء وتطبيع استعلامات الملاعب والمحادثات (Compound Indexes)
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_bookings_stadium_operational 
ON public.bookings (stadium_id, start_time, status);

CREATE INDEX IF NOT EXISTS idx_conversations_participants 
ON public.conversations USING GIN (participant_ids);

CREATE INDEX IF NOT EXISTS idx_teams_gov_points 
ON public.teams (governorate, sport_type, points DESC);

CREATE INDEX IF NOT EXISTS idx_stadiums_discovery_gov 
ON public.stadiums (governorate, is_verified, is_blocked);

CREATE INDEX IF NOT EXISTS idx_tournament_matches_champ_round 
ON public.tournament_matches (championship_id, round_index);


-- ------------------------------------------------------------------------------
-- 7️⃣ ضبط وتحديث الصلاحيات (Granting Permissions)
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.calculate_elo_on_match_completion() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.protect_booking_sensitive_fields() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_user_role_on_signup(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.protect_user_sensitive_fields() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.protect_championship_sensitive_fields() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, UUID[], TEXT[], BOOLEAN, NUMERIC) TO authenticated, service_role;
