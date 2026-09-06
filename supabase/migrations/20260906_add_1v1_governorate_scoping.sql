-- ==============================================================================
-- Migration: 20260906_add_1v1_governorate_scoping.sql
-- Section 1: Governorate Scoping for 1v1 Tournaments
-- ==============================================================================

-- 1️⃣ Standardizer Function for Egypt Governorates
-- Automatically normalizes Arabic/English variants into canonical English names matching users.governorate
CREATE OR REPLACE FUNCTION public.standardize_egypt_governorate(p_gov text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_gov IS NULL OR TRIM(p_gov) = '' THEN
        RETURN 'Cairo';
    END IF;
    
    RETURN CASE LOWER(TRIM(p_gov))
        WHEN 'القاهرة' THEN 'Cairo'
        WHEN 'al qahirah' THEN 'Cairo'
        WHEN 'cairo' THEN 'Cairo'
        WHEN 'الإسكندرية' THEN 'Alexandria'
        WHEN 'الاسكندرية' THEN 'Alexandria'
        WHEN 'alexandria' THEN 'Alexandria'
        WHEN 'alex' THEN 'Alexandria'
        WHEN 'الجيزة' THEN 'Giza'
        WHEN 'giza' THEN 'Giza'
        WHEN 'أسوان' THEN 'Aswan'
        WHEN 'اسوان' THEN 'Aswan'
        WHEN 'aswan' THEN 'Aswan'
        WHEN 'أسيوط' THEN 'Asyut'
        WHEN 'اسيوط' THEN 'Asyut'
        WHEN 'asyut' THEN 'Asyut'
        WHEN 'البحيرة' THEN 'Beheira'
        WHEN 'beheira' THEN 'Beheira'
        WHEN 'بني سويف' THEN 'Beni Suef'
        WHEN 'beni suef' THEN 'Beni Suef'
        WHEN 'الدقهلية' THEN 'Dakahlia'
        WHEN 'dakahlia' THEN 'Dakahlia'
        WHEN 'دمياط' THEN 'Damietta'
        WHEN 'damietta' THEN 'Damietta'
        WHEN 'الفيوم' THEN 'Faiyum'
        WHEN 'faiyum' THEN 'Faiyum'
        WHEN 'الغربية' THEN 'Gharbia'
        WHEN 'gharbia' THEN 'Gharbia'
        WHEN 'الإسماعيلية' THEN 'Ismailia'
        WHEN 'الاسماعيلية' THEN 'Ismailia'
        WHEN 'ismailia' THEN 'Ismailia'
        WHEN 'كفر الشيخ' THEN 'Kafr El Sheikh'
        WHEN 'kafr el sheikh' THEN 'Kafr El Sheikh'
        WHEN 'الأقصر' THEN 'Luxor'
        WHEN 'الاقصر' THEN 'Luxor'
        WHEN 'luxor' THEN 'Luxor'
        WHEN 'مطروح' THEN 'Matrouh'
        WHEN 'مرسى مطروح' THEN 'Matrouh'
        WHEN 'matrouh' THEN 'Matrouh'
        WHEN 'المنيا' THEN 'Minya'
        WHEN 'minya' THEN 'Minya'
        WHEN 'المنوفية' THEN 'Monufia'
        WHEN 'monufia' THEN 'Monufia'
        WHEN 'الوادي الجديد' THEN 'New Valley'
        WHEN 'new valley' THEN 'New Valley'
        WHEN 'شمال سيناء' THEN 'North Sinai'
        WHEN 'north sinai' THEN 'North Sinai'
        WHEN 'بورسعيد' THEN 'Port Said'
        WHEN 'port said' THEN 'Port Said'
        WHEN 'القليوبية' THEN 'Qalyubia'
        WHEN 'qalyubia' THEN 'Qalyubia'
        WHEN 'قنا' THEN 'Qena'
        WHEN 'qena' THEN 'Qena'
        WHEN 'البحر الأحمر' THEN 'Red Sea'
        WHEN 'red sea' THEN 'Red Sea'
        WHEN 'الشرقية' THEN 'Sharqia'
        WHEN 'sharqia' THEN 'Sharqia'
        WHEN 'سوهاج' THEN 'Sohag'
        WHEN 'sohag' THEN 'Sohag'
        WHEN 'جنوب سيناء' THEN 'South Sinai'
        WHEN 'south sinai' THEN 'South Sinai'
        WHEN 'السويس' THEN 'Suez'
        WHEN 'suez' THEN 'Suez'
        ELSE INITCAP(TRIM(p_gov))
    END;
END;
$$;

-- 2️⃣ Add governorate column to vsp_1v1_tournaments
ALTER TABLE public.vsp_1v1_tournaments
ADD COLUMN IF NOT EXISTS governorate TEXT NOT NULL DEFAULT 'Cairo';

CREATE INDEX IF NOT EXISTS idx_vsp_1v1_tournaments_gov ON public.vsp_1v1_tournaments (governorate);

-- Trigger to automatically normalize governorate on insert/update
CREATE OR REPLACE FUNCTION public.trg_standardize_1v1_tournament_governorate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.governorate := public.standardize_egypt_governorate(NEW.governorate);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_1v1_tournament_gov ON public.vsp_1v1_tournaments;
CREATE TRIGGER trg_1v1_tournament_gov
BEFORE INSERT OR UPDATE OF governorate ON public.vsp_1v1_tournaments
FOR EACH ROW
EXECUTE FUNCTION public.trg_standardize_1v1_tournament_governorate();

-- 3️⃣ Drop Old Global Indexes and Add Scoped Unique Index Per Governorate
DROP INDEX IF EXISTS public.idx_one_published_1v1_tournament;
DROP INDEX IF EXISTS public.idx_one_active_1v1_tournament_per_governorate;

CREATE UNIQUE INDEX idx_one_active_1v1_tournament_per_governorate
ON public.vsp_1v1_tournaments (governorate)
WHERE status IN ('registration_open', 'in_progress');

-- 4️⃣ Update publish_1v1_final_standings_atomic (Scoped by governorate)
CREATE OR REPLACE FUNCTION public.publish_1v1_final_standings_atomic(p_tournament_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_champ RECORD;
    v_champion_user_id UUID := NULL;
    v_champion_name TEXT := NULL;
    v_champion_team_id UUID := NULL;
    v_trophy_id UUID;
BEGIN
    -- Admin authorization
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط الأدمن يمكنه اعتماد ونشر النتائج.');
        END IF;
    END IF;

    -- Lock tournament row
    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    -- Find top player by total_points DESC, then goals, skills, tackles
    SELECT user_id, player_name INTO v_champion_user_id, v_champion_name
    FROM public.vsp_1v1_tournament_players
    WHERE tournament_id = p_tournament_id
    ORDER BY total_points DESC, goals DESC, skills DESC, tackles DESC
    LIMIT 1;

    IF v_champion_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يوجد لاعبين مسجلين في البطولة لتتويج بطل.');
    END IF;

    -- Archive previous completed/published tournaments in THIS GOVERNORATE ONLY
    UPDATE public.vsp_1v1_tournaments
    SET status = 'archived'
    WHERE governorate = v_champ.governorate 
      AND status IN ('completed', 'published') 
      AND id != p_tournament_id;

    -- Complete and publish target tournament
    UPDATE public.vsp_1v1_tournaments
    SET 
        status = 'completed',
        published_at = timezone('utc'::text, now()),
        champion_user_id = v_champion_user_id
    WHERE id = p_tournament_id;

    -- Insert trophy
    IF NOT EXISTS (
        SELECT 1 FROM public.player_trophies 
        WHERE user_id = v_champion_user_id 
          AND (tournament_1v1_id = p_tournament_id OR title = 'بطل تحدي 1v1 - ' || COALESCE(v_champ.name, 'VSP 1v1'))
    ) THEN
        INSERT INTO public.player_trophies (
            id,
            user_id,
            tournament_1v1_id,
            title,
            prize_won,
            created_at
        ) VALUES (
            gen_random_uuid(),
            v_champion_user_id,
            p_tournament_id,
            'بطل تحدي 1v1 - ' || COALESCE(v_champ.name, 'VSP 1v1') || ' (' || v_champ.governorate || ')',
            0,
            timezone('utc'::text, now())
        );
    END IF;

    -- Team champion badge
    SELECT team_id INTO v_champion_team_id 
    FROM public.team_members 
    WHERE user_id = v_champion_user_id 
    LIMIT 1;

    IF v_champion_team_id IS NOT NULL THEN
        UPDATE public.teams
        SET has_1v1_champion = true
        WHERE id = v_champion_team_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'governorate', v_champ.governorate,
        'champion_user_id', v_champion_user_id,
        'champion_name', v_champion_name,
        'champion_team_id', v_champion_team_id,
        'status', 'completed'
    );
END;
$$;

-- 5️⃣ Update publish_1v1_tournament_atomic (Scoped by governorate)
CREATE OR REPLACE FUNCTION public.publish_1v1_tournament_atomic(p_tournament_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_champ RECORD;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    SELECT * INTO v_champ FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
    END IF;

    -- Archive whatever was previously published IN THE SAME GOVERNORATE ONLY
    UPDATE public.vsp_1v1_tournaments
    SET status = 'archived'
    WHERE governorate = v_champ.governorate AND status = 'published' AND id != p_tournament_id;

    -- Publish the target tournament
    UPDATE public.vsp_1v1_tournaments
    SET status = 'published', published_at = timezone('utc'::text, now())
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object('success', true, 'tournament_id', p_tournament_id, 'governorate', v_champ.governorate);
END;
$$;

-- 6️⃣ Update create_1v1_payment_order_atomic (Validates caller governorate)
CREATE OR REPLACE FUNCTION public.create_1v1_payment_order_atomic(p_tournament_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_champ RECORD;
    v_current_count INT;
    v_order_id UUID := gen_random_uuid();
    v_order_ref TEXT;
    v_user RECORD;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً للمشاركة.');
    END IF;

    -- Lock tournament row
    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'registration_open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'التسجيل في هذه البطولة مغلق حالياً.');
    END IF;

    -- Fetch caller profile
    SELECT name, profile_image_url, email, phone, governorate INTO v_user 
    FROM public.users 
    WHERE id = v_caller_id;

    -- Enforce governorate matching
    IF v_user.governorate IS NULL OR TRIM(v_user.governorate) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'يرجى تحديد محافظتك في الملف الشخصي أولاً للاشتراك في بطولات منطقتك.');
    END IF;

    IF public.standardize_egypt_governorate(v_user.governorate) != public.standardize_egypt_governorate(v_champ.governorate) THEN
        RETURN jsonb_build_object('success', false, 'error', 'عذراً، هذه البطولة مخصصة لمحافظة ' || v_champ.governorate || ' فقط.');
    END IF;

    -- Check if player is already registered & paid
    IF EXISTS (
        SELECT 1 FROM public.vsp_1v1_tournament_players 
        WHERE tournament_id = p_tournament_id AND user_id = v_caller_id AND payment_status = 'paid'
    ) THEN
        RETURN jsonb_build_object('success', false, 'already_registered', true, 'error', 'أنت مسجل ودافع بالفعل في هذه البطولة.');
    END IF;

    -- Check capacity
    SELECT COUNT(*) INTO v_current_count 
    FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid';

    IF v_current_count >= v_champ.target_player_count THEN
        RETURN jsonb_build_object('success', false, 'error', 'عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.');
    END IF;

    -- Generate clean unique order reference: TOURN_1V1_<short_id>_<timestamp>
    v_order_ref := 'TOURN_1V1_' || SUBSTRING(v_order_id::text, 1, 8) || '_' || FLOOR(EXTRACT(EPOCH FROM now()))::bigint;

    -- Insert pending order record
    INSERT INTO public.vsp_1v1_tournament_orders (
        id,
        tournament_id,
        user_id,
        amount,
        order_reference,
        payment_status,
        created_at,
        updated_at
    ) VALUES (
        v_order_id,
        p_tournament_id,
        v_caller_id,
        COALESCE(v_champ.entry_fee, 0),
        v_order_ref,
        'pending',
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_reference', v_order_ref,
        'amount', COALESCE(v_champ.entry_fee, 0),
        'tournament_id', p_tournament_id,
        'tournament_name', v_champ.name,
        'governorate', v_champ.governorate
    );
END;
$$;
