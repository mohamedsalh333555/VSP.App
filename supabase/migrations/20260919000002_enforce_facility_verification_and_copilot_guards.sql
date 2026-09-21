-- Migration: 20260919000002_enforce_facility_verification_and_copilot_guards.sql
-- Description: Enforces facility verification guard on live stadium activation and blocks premature Pro/Copilot upgrades for unverified venues.

-- 1. Prevent public live booking activation on stadiums if owner is not approved by administration
CREATE OR REPLACE FUNCTION public.check_stadium_live_activation_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner_status TEXT;
    v_has_prices BOOLEAN;
BEGIN
    -- Only check when a stadium is being activated / made visible for live player bookings
    IF (NEW.is_active = TRUE AND (OLD.is_active IS NULL OR OLD.is_active = FALSE)) THEN
        SELECT verification_status INTO v_owner_status
        FROM public.users
        WHERE id = NEW.owner_id;

        IF v_owner_status IS DISTINCT FROM 'approved' THEN
            RAISE EXCEPTION 'لا يمكن تفعيل استقبال الحجوزات للملعب قبل اعتماد أوراق المنشأة رسمياً من الإدارة.';
        END IF;

        -- Ensure price per hour is defined and greater than 0
        IF NEW.price_per_hour IS NULL OR NEW.price_per_hour <= 0 THEN
            RAISE EXCEPTION 'لا يمكن تفعيل استقبال الحجوزات لملعب بدون تحديد سعر الساعة الفعلي.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stadium_live_activation_guard ON public.stadiums;
CREATE TRIGGER trg_stadium_live_activation_guard
BEFORE UPDATE OF is_active, price_per_hour ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.check_stadium_live_activation_guard();

-- 2. Guard against premature Pro/Copilot upgrades for unverified owner facilities
CREATE OR REPLACE FUNCTION public.check_owner_copilot_eligibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- If upgrading subscription_plan to 'pro'
    IF NEW.role = 'owner' AND NEW.subscription_plan = 'pro' AND (OLD.subscription_plan IS DISTINCT FROM 'pro') THEN
        IF NEW.verification_status IS DISTINCT FROM 'approved' THEN
            RAISE EXCEPTION 'لا يمكن الترقية للباقة الاحترافية أو تفعيل VSP Copilot لمنشأة لم يتم اعتماد مستنداتها بعد.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_owner_copilot_eligibility ON public.users;
CREATE TRIGGER trg_check_owner_copilot_eligibility
BEFORE UPDATE OF subscription_plan ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.check_owner_copilot_eligibility();
