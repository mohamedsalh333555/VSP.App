-- ==============================================================================
-- 🚀 VSP MIGRATION: PHASE 2 & 3 AUDIT TRAIL & TECHNICAL DEBT CLEANUP
-- Date: 2026-09-07
-- Description:
-- 1. Creates public.system_audit_logs (Immutable Audit Trail)
-- 2. Creates change-tracking trigger for bookings, stadiums, and payout_settlements
-- 3. Harmonizes stadiums price_per_hour and base_price via trigger
-- ==============================================================================

-- 1️⃣ إنشاء جدول سجل التدقيق والحوكمة الشامل (Immutable System Audit Logs)
CREATE TABLE IF NOT EXISTS public.system_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action TEXT NOT NULL, -- 'UPDATE', 'DELETE'
    changed_by UUID DEFAULT auth.uid(),
    changed_by_role TEXT,
    old_data JSONB,
    new_data JSONB,
    changed_fields TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- فهارس سريعة للبحث والتتبع
CREATE INDEX IF NOT EXISTS idx_audit_logs_record ON public.system_audit_logs (table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_changed_by ON public.system_audit_logs (changed_by);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.system_audit_logs (created_at DESC);

-- حماية السجل بواسطة RLS: متاح للقراءة فقط للمشرفين، وممنوع التعديل أو الحذف نهائياً (Append-Only)
ALTER TABLE public.system_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.system_audit_logs;
CREATE POLICY "Admins can view audit logs" ON public.system_audit_logs
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
    )
);

-- منع التعديل أو الحذف حتى للمستخدمين العاديين
DROP POLICY IF EXISTS "No one can update audit logs" ON public.system_audit_logs;
DROP POLICY IF EXISTS "No one can delete audit logs" ON public.system_audit_logs;


-- 2️⃣ دالة التريجر المركزية لتسجيل التغييرات الحساسة (Generic Audit Logger Trigger)
CREATE OR REPLACE FUNCTION public.fn_log_sensitive_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT := 'system';
    v_changed_keys TEXT[] := ARRAY[]::TEXT[];
    v_old_json JSONB;
    v_new_json JSONB;
    v_key TEXT;
BEGIN
    IF v_user_id IS NOT NULL THEN
        SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);

        -- استخراج الحقول التي تغيرت قيمتها فقط
        FOR v_key IN SELECT jsonb_object_keys(v_new_json)
        LOOP
            IF (v_old_json->v_key IS DISTINCT FROM v_new_json->v_key) THEN
                v_changed_keys := array_append(v_changed_keys, v_key);
            END IF;
        END LOOP;

        -- إذا لم تتغير سوى حقول التوقيت updated_at فلا داعي لملء السجل
        IF v_changed_keys = ARRAY['updated_at']::TEXT[] OR array_length(v_changed_keys, 1) IS NULL THEN
            RETURN NEW;
        END IF;

        INSERT INTO public.system_audit_logs (
            table_name,
            record_id,
            action,
            changed_by,
            changed_by_role,
            old_data,
            new_data,
            changed_fields,
            created_at
        ) VALUES (
            TG_TABLE_NAME,
            NEW.id,
            'UPDATE',
            v_user_id,
            v_user_role,
            v_old_json,
            v_new_json,
            v_changed_keys,
            timezone('utc'::text, now())
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.system_audit_logs (
            table_name,
            record_id,
            action,
            changed_by,
            changed_by_role,
            old_data,
            new_data,
            changed_fields,
            created_at
        ) VALUES (
            TG_TABLE_NAME,
            OLD.id,
            'DELETE',
            v_user_id,
            v_user_role,
            to_jsonb(OLD),
            NULL,
            ARRAY['*FULL_ROW_DELETED*']::TEXT[],
            timezone('utc'::text, now())
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;


-- تفعيل التريجر على جدول الحجوزات bookings
DROP TRIGGER IF EXISTS trg_audit_bookings ON public.bookings;
CREATE TRIGGER trg_audit_bookings
AFTER UPDATE OR DELETE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.fn_log_sensitive_changes();

-- تفعيل التريجر على جدول الملاعب stadiums
DROP TRIGGER IF EXISTS trg_audit_stadiums ON public.stadiums;
CREATE TRIGGER trg_audit_stadiums
AFTER UPDATE OR DELETE ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.fn_log_sensitive_changes();

-- تفعيل التريجر على جدول التسويات المالية payout_settlements
DROP TRIGGER IF EXISTS trg_audit_payouts ON public.payout_settlements;
CREATE TRIGGER trg_audit_payouts
AFTER UPDATE OR DELETE ON public.payout_settlements
FOR EACH ROW
EXECUTE FUNCTION public.fn_log_sensitive_changes();


-- 3️⃣ سداد الدين التقني: المزامنة التلقائية لأسعار الملاعب (Harmonize price_per_hour & base_price)
CREATE OR REPLACE FUNCTION public.fn_sync_stadium_prices()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- ضمان تطابق الحقلين دائماً سواء تم التعديل على هذا أو ذاك
    IF NEW.price_per_hour IS NOT NULL AND NEW.base_price IS NULL THEN
        NEW.base_price := NEW.price_per_hour;
    ELSIF NEW.base_price IS NOT NULL AND NEW.price_per_hour IS NULL THEN
        NEW.price_per_hour := NEW.base_price;
    ELSIF NEW.price_per_hour IS NOT NULL AND (OLD IS NULL OR NEW.price_per_hour IS DISTINCT FROM OLD.price_per_hour) THEN
        NEW.base_price := NEW.price_per_hour;
    ELSIF NEW.base_price IS NOT NULL AND (OLD IS NULL OR NEW.base_price IS DISTINCT FROM OLD.base_price) THEN
        NEW.price_per_hour := NEW.base_price;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_stadium_prices ON public.stadiums;
CREATE TRIGGER trg_sync_stadium_prices
BEFORE INSERT OR UPDATE OF price_per_hour, base_price ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_stadium_prices();
