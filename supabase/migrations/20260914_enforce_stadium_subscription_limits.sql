-- Migration: 20260914_enforce_stadium_subscription_limits.sql
-- Description: Enforces maximum stadium limit per owner based on their active subscription plan at database level.

CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner RECORD;
    v_current_count INT;
    v_max_allowed INT := 0;
    v_is_active_trial BOOLEAN := FALSE;
    v_is_sub_active BOOLEAN := FALSE;
BEGIN
    -- 1. Ignore if owner_id is null
    IF NEW.owner_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Fetch owner details
    SELECT role, subscription_plan, subscription_expires_at, trial_ends_at, created_at
    INTO v_owner
    FROM public.users
    WHERE id = NEW.owner_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'مالك الملعب المحدد غير موجود في النظام.';
    END IF;

    -- Admins and Co-Founders are exempt from subscription limits
    IF v_owner.role IN ('admin', 'co_founder') THEN
        RETURN NEW;
    END IF;

    -- Check trial validity (explicit trial_ends_at or 60-day fallback from creation)
    v_is_active_trial := (
        COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
        (
            (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
            (v_owner.trial_ends_at IS NULL AND v_owner.created_at + INTERVAL '60 days' > NOW())
        )
    );

    -- Check subscription validity
    v_is_sub_active := (
        v_owner.subscription_expires_at IS NOT NULL AND v_owner.subscription_expires_at > NOW()
    );

    -- Determine max stadiums allowed
    IF v_owner.subscription_plan = 'pro' AND v_is_sub_active THEN
        v_max_allowed := 3;
    ELSIF (v_owner.subscription_plan = 'basic' AND v_is_sub_active) OR v_is_active_trial THEN
        v_max_allowed := 1;
    ELSE
        v_max_allowed := 0;
    END IF;

    -- 3. Count existing active (non-deleted) stadiums for this owner
    SELECT COUNT(*) INTO v_current_count
    FROM public.stadiums
    WHERE owner_id = NEW.owner_id
      AND is_deleted_by_owner = false;

    -- 4. Enforce limit
    IF v_current_count >= v_max_allowed THEN
        IF v_max_allowed = 0 THEN
            RAISE EXCEPTION 'انتهت صلاحية باقة الاشتراك الخاصة بك. يرجى تجديد الاشتراك لإضافة ملاعب.';
        ELSE
            RAISE EXCEPTION 'وصلت للحد الأقصى للملاعب في باقتك الحالية (% ملعب). يرجى الترقية لإضافة ملاعب أخرى.', v_max_allowed;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_owner_stadium_limit ON public.stadiums;
CREATE TRIGGER trg_enforce_owner_stadium_limit
BEFORE INSERT ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.check_owner_stadium_limit_trigger();
