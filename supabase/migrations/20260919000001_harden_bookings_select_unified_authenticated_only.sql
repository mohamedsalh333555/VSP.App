-- ==============================================================================
-- 🛡️ VSP MIGRATION: 20260919000001_harden_bookings_select_unified_authenticated_only.sql
-- 1. Restrict bookings_select_unified from TO public to TO authenticated
--    Prevents anonymous web scraping of bookings while preserving access for registered players
-- 2. Provide atomic admin_toggle_user_block RPC so admin panel does not rely on direct table updates
-- ==============================================================================

BEGIN;

-- 1️⃣ تحصين قراءة الحجوزات: قصرها على المستخدمين المسجلين فقط
DROP POLICY IF EXISTS "bookings_select_unified" ON public."bookings";

CREATE POLICY "bookings_select_unified" ON public."bookings" 
AS PERMISSIVE FOR SELECT TO authenticated 
USING (
  (((select auth.uid()) = user_id) 
  OR ((select auth.uid()) = owner_id) 
  OR ((select auth.uid()) = created_by_user_id) 
  OR (is_private = false) 
  OR ((select auth.uid()) = ANY (COALESCE(joined_user_ids, ARRAY[]::uuid[]))))
);

-- 2️⃣ إجراء ذري لحظر أو إلغاء حظر المستخدمين وملاعبهم من لوحة الإدارة
CREATE OR REPLACE FUNCTION public.admin_toggle_user_block(
    p_user_id UUID,
    p_is_blocked BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    -- التحقق الصارم من صلاحيات الأدمن
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    UPDATE public.users
    SET is_blocked = p_is_blocked,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id;

    UPDATE public.stadiums
    SET is_blocked = p_is_blocked,
        updated_at = timezone('utc'::text, now())
    WHERE owner_id = p_user_id;

    RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'is_blocked', p_is_blocked);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_toggle_user_block(UUID, BOOLEAN) TO authenticated, service_role;

COMMIT;
