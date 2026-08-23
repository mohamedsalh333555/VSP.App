-- ==============================================================================
-- 🚀 VSP PLATFORM — OWNER SUBSCRIPTION UPGRADE & REALTIME SYNC PATCH
-- Description: Atomic Admin Subscription Upgrade RPC with Automated Push Notification
-- Date: 2026-08-23
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ دالة ترقية باقة المالك ذرّياً مع إشعار تلقائي (admin_upgrade_owner_subscription_atomic)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_upgrade_owner_subscription_atomic(UUID, TEXT, INT);

CREATE OR REPLACE FUNCTION public.admin_upgrade_owner_subscription_atomic(
    p_owner_id UUID,
    p_plan TEXT,
    p_days INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_uid UUID := auth.uid();
    v_admin_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_expires_at TIMESTAMPTZ;
    v_plan_title TEXT;
BEGIN
    -- 1. التحقق من صلاحيات الأدمن
    SELECT role INTO v_admin_role FROM public.users WHERE id = v_admin_uid;
    IF v_admin_role NOT IN ('admin', 'co_founder') AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
    END IF;

    -- 2. التحقق من صحة الباقة
    IF p_plan NOT IN ('free_trial', 'basic', 'pro') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid subscription plan');
    END IF;

    v_expires_at := v_now + (p_days || ' days')::interval;

    -- 3. تحديث باقة المالك
    IF p_plan = 'free_trial' THEN
        UPDATE public.users
        SET 
            subscription_plan = 'free_trial',
            trial_ends_at = v_expires_at,
            subscription_expires_at = NULL,
            updated_at = v_now
        WHERE id = p_owner_id;
        v_plan_title := 'الفترة التجريبية المجانية';
    ELSE
        UPDATE public.users
        SET 
            subscription_plan = p_plan,
            subscription_expires_at = v_expires_at,
            updated_at = v_now
        WHERE id = p_owner_id;
        v_plan_title := CASE WHEN p_plan = 'pro' THEN 'الباقة الاحترافية (Pro 👑)' ELSE 'الباقة الأساسية (Basic)' END;
    END IF;

    -- 4. إرسال إشعار فوري للمالك
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        is_read,
        created_at
    ) VALUES (
        p_owner_id,
        'تم ترقية اشتراكك بنجاح! 🏆',
        'تهانينا! تم تفعيل ' || v_plan_title || ' لمدة ' || p_days || ' يوماً. استمتع بكامل المزايا الآن.',
        'subscription',
        false,
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'plan', p_plan,
        'expires_at', v_expires_at,
        'message', 'Owner subscription upgraded successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2️⃣ منح الصلاحيات (Grant Permissions)
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.admin_upgrade_owner_subscription_atomic(UUID, TEXT, INT) TO authenticated, service_role;

COMMIT;
