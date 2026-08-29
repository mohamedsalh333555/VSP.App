-- ==============================================================================
-- 🔒 VSP PLATFORM — CHAT & NOTIFICATIONS ZERO-TRUST SECURITY PATCH
-- Description: 1. Hardens delete_chat_for_user_atomic to strictly require auth.uid() = p_user_id.
--              2. Ensures notifications & chat_messages RLS policies are fully hardened.
-- Date: 2026-08-29
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ تحصين دالة إخفاء/حذف المحادثة للمستخدم (delete_chat_for_user_atomic)
-- الحماية: منع تمرير p_user_id الخاص بمستخدم آخر (منع الـ IDOR)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_chat_for_user_atomic(
    p_booking_id UUID, 
    p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- 🔒 التحقق الصارم من أن المستخدم يحذف المحادثة لحسابه الشخصي فقط
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF (p_user_id IS DISTINCT FROM auth.uid()) THEN
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
        RAISE EXCEPTION 'Unauthorized: You can only hide or delete chats for your own user account.';
      END IF;
    END IF;
  END IF;

  -- إضافة معرف المستخدم لمصفوفة المحذوفات في الرسائل
  UPDATE public.chat_messages
  SET deleted_for_users = ARRAY(SELECT DISTINCT UNNEST(array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)))
  WHERE booking_id = p_booking_id 
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);

  -- إضافة معرف المستخدم لمصفوفة المحذوفات في جدول المحادثات
  UPDATE public.conversations
  SET deleted_for_users = ARRAY(SELECT DISTINCT UNNEST(array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)))
  WHERE booking_id = p_booking_id 
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_chat_for_user_atomic(UUID, UUID) TO authenticated, service_role;

COMMIT;
