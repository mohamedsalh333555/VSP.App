-- Migration: 20260923000000_update_free_trial_to_one_year.sql
-- Description: Update owner free trial duration from 60 days (2 months) to 365 days (1 year) across database functions, triggers, and existing owner accounts.

-- 1️⃣ تحديث دالة RPC: check_owner_stadium_limit(p_owner_id uuid)
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_owner RECORD;
    v_count INT;
    v_max_allowed INT := 0;
    v_is_active_trial BOOLEAN := FALSE;
    v_is_sub_active BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', false, 'message', 'المستخدم غير موجود.');
    END IF;

    IF v_owner.role IN ('admin', 'co_founder', 'super_admin') THEN
        RETURN jsonb_build_object('allowed', true, 'current_count', 0, 'max_allowed', 999);
    END IF;

    -- التحقق من صلاحية الفترة التجريبية (إما تاريخ صريح أو مهلة 365 يوماً / سنة كاملة من تاريخ الإنشاء)
    v_is_active_trial := (
        COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
        (
            (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
            (v_owner.trial_ends_at IS NULL AND v_owner.created_at + INTERVAL '365 days' > NOW())
        )
    );

    v_is_sub_active := (
        v_owner.subscription_expires_at IS NOT NULL AND v_owner.subscription_expires_at > NOW()
    );

    IF v_owner.subscription_plan = 'pro' AND v_is_sub_active THEN
        v_max_allowed := 3;
    ELSIF (v_owner.subscription_plan = 'basic' AND v_is_sub_active) OR v_is_active_trial THEN
        v_max_allowed := 1;
    ELSE
        v_max_allowed := 0;
    END IF;

    SELECT COUNT(*) INTO v_count 
    FROM public.stadiums 
    WHERE owner_id = p_owner_id AND is_deleted_by_owner = false;

    IF v_count >= v_max_allowed THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'current_count', v_count,
            'max_allowed', v_max_allowed,
            'message', 'لقد وصلت للحد الأقصى للملاعب المسموح بها في باقتك (' || v_max_allowed || ' ملاعب). يرجى ترقية باقتك لإضافة ملاعب جديدة.'
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'current_count', v_count,
        'max_allowed', v_max_allowed
    );
END;
$function$;

-- 2️⃣ تحديث تريجر التحقق عند إضافة الملاعب: check_owner_stadium_limit()
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_owner RECORD;
    v_current_count INT;
    v_max_allowed INT := 0;
    v_is_active_trial BOOLEAN := FALSE;
    v_is_sub_active BOOLEAN := FALSE;
BEGIN
    PERFORM id
    FROM public.users
    WHERE id = NEW.owner_id
    FOR UPDATE;

    SELECT role, subscription_plan, subscription_expires_at, trial_ends_at, created_at
    INTO v_owner
    FROM public.users
    WHERE id = NEW.owner_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'مالك الملعب المحدد غير موجود في النظام.';
    END IF;

    IF v_owner.role IN ('admin', 'co_founder', 'super_admin') THEN
        RETURN NEW;
    END IF;

    -- التحقق من صلاحية الفترة التجريبية (إما تاريخ صريح أو مهلة سنة كاملة / 365 يوماً من تاريخ الإنشاء)
    v_is_active_trial := (
        COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
        (
            (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
            (v_owner.trial_ends_at IS NULL AND v_owner.created_at + INTERVAL '365 days' > NOW())
        )
    );

    v_is_sub_active := (
        v_owner.subscription_expires_at IS NOT NULL AND v_owner.subscription_expires_at > NOW()
    );

    IF v_owner.subscription_plan = 'pro' AND v_is_sub_active THEN
        v_max_allowed := 3;
    ELSIF (v_owner.subscription_plan = 'basic' AND v_is_sub_active) OR v_is_active_trial THEN
        v_max_allowed := 1;
    ELSE
        v_max_allowed := 0;
    END IF;

    SELECT COUNT(*) INTO v_current_count
    FROM public.stadiums
    WHERE owner_id = NEW.owner_id
      AND is_deleted_by_owner = false
      AND (TG_OP = 'INSERT' OR id <> NEW.id);

    IF v_current_count >= v_max_allowed THEN
        RAISE EXCEPTION 'BLOCKED_SUBSCRIPTION_LIMIT: وصلت للحد الأقصى للملاعب المسموح بها في باقتك الحالية (% ملعب). قم بترقية باقتك لإضافة ملاعب أخرى.', v_max_allowed;
    END IF;

    RETURN NEW;
END;
$function$;

-- 3️⃣ تمديد الفترة التجريبية لجميع حسابات الملاك الحاليين في النظام لتصبح سنة كاملة من تاريخ تسجيلهم
UPDATE public.users
SET 
    trial_ends_at = created_at + INTERVAL '365 days',
    updated_at = timezone('utc'::text, now())
WHERE role = 'owner'
  AND COALESCE(subscription_plan, 'free_trial') = 'free_trial'
  AND (trial_ends_at IS NULL OR trial_ends_at < created_at + INTERVAL '365 days');
