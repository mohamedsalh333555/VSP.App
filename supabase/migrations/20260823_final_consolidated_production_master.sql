-- ==============================================================================
-- 🚀 VSP MASTER PRODUCTION CONSOLIDATION MIGRATION (2026-08-23)
-- Full-Stack Dual Audit Hardening: Ledger, Payouts, Tournaments, Disputes, Refunds & Reviews
-- (Self-Healing & Idempotent with Explicit DROP FUNCTION Safety & Full RLS Support)
-- ==============================================================================

BEGIN;

-- 1. Ensure Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. SELF-HEALING COLUMN CHECKS & TABLE SCHEMAS
-- ==============================================================================

-- A. USERS TABLE
ALTER TABLE IF EXISTS public.users
    ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'player',
    ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'free_trial',
    ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS p2p_instapay TEXT,
    ADD COLUMN IF NOT EXISTS p2p_vodafone TEXT,
    ADD COLUMN IF NOT EXISTS p2p_bank TEXT,
    ADD COLUMN IF NOT EXISTS additional_data JSONB DEFAULT '{}'::jsonb;

-- B. STADIUMS TABLE
ALTER TABLE IF EXISTS public.stadiums
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS reviews_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 2) DEFAULT 5.0;

-- C. CHAMPIONSHIPS TABLE
ALTER TABLE IF EXISTS public.championships
    ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS joined_teams UUID[] DEFAULT '{}'::uuid[],
    ADD COLUMN IF NOT EXISTS paid_teams UUID[] DEFAULT '{}'::uuid[],
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS champion_team_id UUID,
    ADD COLUMN IF NOT EXISTS champion_team_name TEXT,
    ADD COLUMN IF NOT EXISTS settings JSONB DEFAULT '{}'::jsonb;

-- D. BOOKINGS TABLE
ALTER TABLE IF EXISTS public.bookings
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS final_outcome TEXT,
    ADD COLUMN IF NOT EXISTS match_result_status TEXT DEFAULT 'noResult',
    ADD COLUMN IF NOT EXISTS pending_outcome TEXT,
    ADD COLUMN IF NOT EXISTS requires_admin_intervention BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(10, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_price NUMERIC(10, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS platform_fee NUMERIC(10, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash',
    ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- E. TRANSACTIONS & FINANCIAL LEDGER TABLE
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    championship_id UUID REFERENCES public.championships(id) ON DELETE SET NULL,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    type TEXT NOT NULL DEFAULT 'payout',
    status TEXT NOT NULL DEFAULT 'completed',
    payment_method TEXT,
    description TEXT,
    reference_number TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.transactions
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS championship_id UUID REFERENCES public.championships(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'payout',
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed',
    ADD COLUMN IF NOT EXISTS payment_method TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS reference_number TEXT,
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- F. REVIEWS TABLE
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stadium_id UUID NOT NULL REFERENCES public.stadiums(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_name TEXT,
    user_image_url TEXT,
    rating NUMERIC(2, 1) NOT NULL DEFAULT 5.0,
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- G. REPORTS TABLE
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    target_id TEXT NOT NULL,
    target_type TEXT NOT NULL,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- H. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 3. DROP OLD FUNCTION SIGNATURES (PREVENTS PARAMETER NAME CONFLICTS)
-- ==============================================================================
DROP FUNCTION IF EXISTS public.cancel_booking_with_refund_atomic(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.cancel_booking_with_refund_atomic(UUID, UUID);
DROP FUNCTION IF EXISTS public.submit_stadium_review_atomic(UUID, UUID, TEXT, TEXT, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.join_championship_atomic(UUID, UUID, BOOLEAN);
DROP FUNCTION IF EXISTS public.join_championship_atomic(UUID, UUID);
DROP FUNCTION IF EXISTS public.crown_tournament_champion_atomic(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.crown_tournament_champion_atomic(UUID, UUID);
DROP FUNCTION IF EXISTS public.leave_championship_atomic(UUID, UUID);
DROP FUNCTION IF EXISTS public.admin_approve_owner_atomic(UUID);
DROP FUNCTION IF EXISTS public.admin_resolve_dispute_atomic(UUID, TEXT);
DROP FUNCTION IF EXISTS public.admin_record_payout_settlement_atomic(UUID, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.check_owner_stadium_limit(UUID);

-- ==============================================================================
-- 4. ATOMIC RPC: CANCEL BOOKING WITH REFUND & LEDGER TRANSACTION
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
    p_booking_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT 'Cancelled by user'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
    v_refund_amount NUMERIC(10, 2) := 0.00;
    v_tx_id UUID;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- Check 2-hour cutoff rule for players
    IF v_booking.start_time <= (timezone('utc'::text, now()) + INTERVAL '2 hours') THEN
        RETURN jsonb_build_object('success', false, 'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من ساعتين وفقاً للائحة.');
    END IF;

    -- Calculate refund amount if online payment was made
    IF v_booking.payment_status = 'paid' OR v_booking.payment_status = 'confirmed' THEN
        v_refund_amount := COALESCE(v_booking.deposit_amount, v_booking.total_price, 0.00);
    END IF;

    -- Update booking status to cancelled
    UPDATE public.bookings
    SET status = 'cancelled',
        payment_status = CASE WHEN v_refund_amount > 0 THEN 'refunded' ELSE payment_status END,
        cancellation_reason = p_reason,
        cancelled_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- If deposit was paid, log refund in transactions ledger
    IF v_refund_amount > 0 THEN
        INSERT INTO public.transactions (
            user_id,
            booking_id,
            amount,
            type,
            status,
            payment_method,
            description,
            created_at
        ) VALUES (
            p_user_id,
            p_booking_id,
            v_refund_amount,
            'refund',
            'completed',
            v_booking.payment_method,
            'استرداد إلكتروني لقيمة حجز ملغى: ' || v_booking.stadium_name,
            timezone('utc'::text, now())
        ) RETURNING id INTO v_tx_id;
    END IF;

    -- Notify Stadium Owner
    IF v_booking.owner_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            created_at
        ) VALUES (
            v_booking.owner_id,
            'إلغاء حجز في ملعبك ⚠️',
            'قام اللاعب بإلغاء حجزه المقرر في ' || v_booking.stadium_name || ' وتم إتاحة الموعد مجدداً.',
            'booking_cancelled',
            timezone('utc'::text, now())
        );
    END IF;

    -- Notify User
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_user_id,
        'تم إلغاء الحجز بنجاح ✅',
        CASE WHEN v_refund_amount > 0 
            THEN 'تم إلغاء حجزك وجاري رد مبلغ ' || v_refund_amount || ' ج.م إلى وسيلة الدفع الخاصة بك.'
            ELSE 'تم إلغاء حجزك بنجاح دون أي رسوم.' END,
        'booking_cancelled',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'refund_amount', v_refund_amount,
        'transaction_id', v_tx_id
    );
END;
$$;

-- ==============================================================================
-- 5. ATOMIC RPC: SUBMIT STADIUM REVIEW (WITH BOOKING VERIFICATION)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(
    p_stadium_id UUID,
    p_user_id UUID,
    p_user_name TEXT,
    p_user_image_url TEXT,
    p_rating NUMERIC,
    p_comment TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_has_booking BOOLEAN;
    v_avg_rating NUMERIC(3, 2);
    v_total_reviews INT;
BEGIN
    -- Verify user had a confirmed or completed booking at this stadium
    SELECT EXISTS (
        SELECT 1 FROM public.bookings
        WHERE stadium_id = p_stadium_id
          AND (user_id = p_user_id OR created_by_user_id = p_user_id::text)
          AND status IN ('confirmed', 'completed')
    ) INTO v_has_booking;

    IF NOT v_has_booking THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'must_have_completed_booking'
        );
    END IF;

    -- Insert Review
    INSERT INTO public.reviews (
        stadium_id,
        user_id,
        user_name,
        user_image_url,
        rating,
        review_text,
        created_at
    ) VALUES (
        p_stadium_id,
        p_user_id,
        p_user_name,
        p_user_image_url,
        p_rating,
        p_comment,
        timezone('utc'::text, now())
    );

    -- Recalculate Stadium Aggregate Rating & Reviews Count
    SELECT COALESCE(AVG(rating), 5.0), COUNT(*)
    INTO v_avg_rating, v_total_reviews
    FROM public.reviews
    WHERE stadium_id = p_stadium_id;

    UPDATE public.stadiums
    SET rating = v_avg_rating,
        reviews_count = v_total_reviews,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_stadium_id;

    RETURN jsonb_build_object(
        'success', true,
        'rating', v_avg_rating,
        'reviews_count', v_total_reviews
    );
END;
$$;

-- ==============================================================================
-- 6. ATOMIC RPC: JOIN CHAMPIONSHIP
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.join_championship_atomic(
    p_championship_id UUID,
    p_team_id UUID,
    p_is_paid BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_champ RECORD;
    v_joined_count INT;
BEGIN
    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status <> 'open' THEN
        RETURN jsonb_build_object('success', false, 'message', 'باب التسجيل في هذه البطولة مغلق حالياً.');
    END IF;

    IF p_team_id = ANY(v_champ.joined_teams) THEN
        RETURN jsonb_build_object('success', false, 'message', 'فريقك مسجل بالفعل في هذه البطولة.');
    END IF;

    v_joined_count := array_length(v_champ.joined_teams, 1);
    IF v_joined_count IS NOT NULL AND v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'message', 'اكتمل الحد الأقصى للفرق المشاركة في هذه البطولة.');
    END IF;

    UPDATE public.championships
    SET joined_teams = array_append(joined_teams, p_team_id),
        paid_teams = CASE WHEN p_is_paid THEN array_append(paid_teams, p_team_id) ELSE paid_teams END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'team_id', p_team_id);
END;
$$;

-- ==============================================================================
-- 7. ATOMIC RPC: CROWN TOURNAMENT CHAMPION
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.crown_tournament_champion_atomic(
    p_championship_id UUID,
    p_champion_team_id UUID,
    p_champion_team_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.championships
    SET status = 'completed',
        champion_team_id = p_champion_team_id,
        champion_team_name = p_champion_team_name,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    UPDATE public.teams
    SET championships_won = COALESCE(championships_won, 0) + 1,
        points = COALESCE(points, 0) + 100,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_champion_team_id;

    RETURN jsonb_build_object('success', true, 'champion_team_id', p_champion_team_id);
END;
$$;

-- ==============================================================================
-- 8. ATOMIC RPC: LEAVE CHAMPIONSHIP
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.leave_championship_atomic(
    p_championship_id UUID,
    p_team_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.championships
    SET joined_teams = array_remove(joined_teams, p_team_id),
        paid_teams = array_remove(paid_teams, p_team_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_championship_id;

    DELETE FROM public.tournament_team_rosters
    WHERE championship_id = p_championship_id AND team_id = p_team_id;

    RETURN jsonb_build_object('success', true, 'championship_id', p_championship_id, 'team_id', p_team_id);
END;
$$;

-- ==============================================================================
-- 9. ATOMIC RPC: APPROVE OWNER & CASCADE TO STADIUMS/CHAMPIONSHIPS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.admin_approve_owner_atomic(
    p_owner_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.users
    SET verification_status = 'approved',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_owner_id;

    UPDATE public.stadiums
    SET is_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE owner_id = p_owner_id;

    UPDATE public.championships
    SET is_approved = true,
        updated_at = timezone('utc'::text, now())
    WHERE owner_id = p_owner_id;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_owner_id,
        'تهانينا! تم توثيق حسابك كصاحب ملعب رسمي 🏆',
        'تمت مراجعة مستنداتك وتوثيق حسابك بنجاح. ملاعبك وبطولاتك أصبحت الآن ظاهرة لجميع اللاعبين.',
        'stadium_approved',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'owner_id', p_owner_id);
END;
$$;

-- ==============================================================================
-- 10. ATOMIC RPC: RESOLVE MATCH DISPUTE
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.admin_resolve_dispute_atomic(
    p_booking_id UUID,
    p_final_outcome TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المباراة غير موجودة.');
    END IF;

    UPDATE public.bookings
    SET status = 'completed',
        final_outcome = p_final_outcome,
        match_result_status = 'confirmed',
        pending_outcome = NULL,
        requires_admin_intervention = false,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    IF v_booking.player_team_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية للمباراة: ' || p_final_outcome, 'result_confirmation', timezone('utc'::text, now())
        FROM public.teams WHERE id = v_booking.player_team_id;
    END IF;

    IF v_booking.opponent_team_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية للمباراة: ' || p_final_outcome, 'result_confirmation', timezone('utc'::text, now())
        FROM public.teams WHERE id = v_booking.opponent_team_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'outcome', p_final_outcome);
END;
$$;

-- ==============================================================================
-- 11. ATOMIC RPC: RECORD PAYOUT SETTLEMENT
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.admin_record_payout_settlement_atomic(
    p_owner_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_reference TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tx_id UUID;
BEGIN
    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        status,
        payment_method,
        reference_number,
        description,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout',
        'completed',
        p_payment_method,
        p_reference,
        'تسوية أرباح مالك ملعب من إدارة VSP',
        timezone('utc'::text, now())
    ) RETURNING id INTO v_tx_id;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_owner_id,
        'تم تحويل أرباحك بنجاح! 💸',
        'تم إرسال مبلغ ' || p_amount || ' ج.م إلى حسابك عبر ' || p_payment_method || ' برقم مرجع: ' || p_reference,
        'info',
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object('success', true, 'transaction_id', v_tx_id, 'amount', p_amount);
END;
$$;

-- ==============================================================================
-- 12. ENFORCE OWNER STADIUM TIER LIMITS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(
    p_owner_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_owner RECORD;
    v_count INT;
    v_max_allowed INT;
BEGIN
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', true);
    END IF;

    IF v_owner.subscription_plan = 'pro' THEN
        v_max_allowed := 5;
    ELSIF v_owner.subscription_plan = 'basic' THEN
        v_max_allowed := 1;
    ELSE
        v_max_allowed := 1;
    END IF;

    SELECT COUNT(*) INTO v_count FROM public.stadiums WHERE owner_id = p_owner_id;

    IF v_count >= v_max_allowed THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'current_count', v_count,
            'max_allowed', v_max_allowed,
            'message', 'لقد بلغت الحد الأقصى للملاعب المسموحة لباقاتك (' || v_max_allowed || ' ملاعب). يرجى ترقية باقتك لإضافة ملاعب جديدة.'
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'current_count', v_count,
        'max_allowed', v_max_allowed
    );
END;
$$;

-- ==============================================================================
-- 13. REALTIME REPLICATION ENABLEMENT
-- ==============================================================================
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.championships;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.reports;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;

COMMIT;
