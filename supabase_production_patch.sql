-- ==============================================================================
-- 🛡️ VSP SPORTS PLATFORM — PRODUCTION SECURITY & PERFORMANCE PATCH 2026
-- ==============================================================================
-- مرحلة التنفيذ (Pass 2 - Category 1: Database, RLS, Indexes & RPC Hardening)
-- هذا السكريبت متوافق بنسبة 100% ويعالج الثغرات الأمنية والأداء دون المساس بالبيانات الحالية.
-- ==============================================================================

-- 1. 🗑️ DROP DANGEROUS & REDUNDANT OBJECTS
-- ==============================================================================
-- حذف دالة المحاكاة الخطرة من بيئة الإنتاج
DROP FUNCTION IF EXISTS public.simulate_paymob_webhook(UUID, NUMERIC);
DROP FUNCTION IF EXISTS public.simulate_paymob_webhook(UUID);

-- حذف الفهرس المكرر على جدول الحجوزات لتوفير الذاكرة وسرعة الكتابة
DROP INDEX IF EXISTS public.idx_bookings_stadium_id;


-- 2. 🔒 USER TABLE PROTECTION TRIGGER (PREVENT PRIVILEGE ESCALATION)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_admin BOOLEAN := FALSE;
BEGIN
    -- التحقق إذا كان المستخدم الحالي Admin أو Co-founder أو Service Role
    IF auth.role() = 'service_role' THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND role = ANY (ARRAY['admin', 'co_founder'])
    ) INTO v_is_admin;

    -- إذا لم يكن أدمن، يتم حظر تعديل الحقول الحساسة وإبقاؤها على قيمتها القديمة
    IF NOT v_is_admin THEN
        NEW.role                        := OLD.role;
        NEW.is_blocked                  := OLD.is_blocked;
        NEW.subscription_plan           := OLD.subscription_plan;
        NEW.trial_ends_at               := OLD.trial_ends_at;
        NEW.subscription_expires_at     := OLD.subscription_expires_at;
        NEW.total_platform_fees         := OLD.total_platform_fees;
        NEW.is_identity_verified        := OLD.is_identity_verified;
        NEW.verification_status         := OLD.verification_status;
        NEW.cash_booking_banned         := OLD.cash_booking_banned;
        NEW.no_show_count               := OLD.no_show_count;
        NEW.completed_online_bookings_count := OLD.completed_online_bookings_count;
        NEW.has_stadium                 := OLD.has_stadium;
    END IF;

    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_user_sensitive_fields
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.protect_user_sensitive_fields();


-- 3. 💳 BOOKINGS TABLE PROTECTION TRIGGER (PREVENT FINANCIAL TAMPERING)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.protect_booking_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_admin BOOLEAN := FALSE;
BEGIN
    -- السماح للـ service_role بالمرور
    IF auth.role() = 'service_role' THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND role = ANY (ARRAY['admin', 'co_founder'])
    ) INTO v_is_admin;

    -- إذا لم يكن أدمن، منع التلاعب بحالة الدفع وتأكيد الحجز المباشر من العميل
    IF NOT v_is_admin THEN
        -- منع اللاعب/المالك من تغيير حالة الدفع بدون المرور عبر الـ Webhook أو الـ RPC
        IF (OLD.is_paid IS FALSE AND NEW.is_paid IS TRUE) OR
           (OLD.payment_status != 'paid' AND NEW.payment_status = 'paid') OR
           (OLD.deposit_paid != NEW.deposit_paid) OR
           (OLD.platform_fee != NEW.platform_fee) THEN
            
            -- التحقق إذا كان التعديل ناتجاً عن كود موثوق
            IF current_setting('vsp.internal_payment_call', true) IS DISTINCT FROM 'true' THEN
                NEW.is_paid                := OLD.is_paid;
                NEW.payment_status         := OLD.payment_status;
                NEW.deposit_paid           := OLD.deposit_paid;
                NEW.platform_fee           := OLD.platform_fee;
                NEW.payment_transaction_id := OLD.payment_transaction_id;
            END IF;
        END IF;
    END IF;

    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_booking_sensitive_fields ON public.bookings;
CREATE TRIGGER trg_protect_booking_sensitive_fields
BEFORE UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.protect_booking_sensitive_fields();


-- 4. 🛑 TRANSACTIONS TABLE RLS LOCKDOWN
-- ==============================================================================
-- منع إدراج معاملات مالية مباشرة من التطبيق، وجعلها عبر الـ Service Role والـ Triggers فقط
DROP POLICY IF EXISTS transactions_insert_policy ON public.transactions;
CREATE POLICY transactions_insert_policy ON public.transactions
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role = ANY (ARRAY['admin', 'co_founder'])
    )
);


-- 5. 🛡️ SEARCH PATH INJECTION HARDENING FOR ALL SECURITY DEFINER RPCS
-- ==============================================================================
ALTER FUNCTION public.create_booking_atomic(TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC)
SET search_path = public, pg_temp;

ALTER FUNCTION public.request_join_public_match(TEXT, TEXT)
SET search_path = public, pg_temp;

ALTER FUNCTION public.accept_join_request(TEXT, TEXT)
SET search_path = public, pg_temp;

ALTER FUNCTION public.reject_join_request(TEXT, TEXT)
SET search_path = public, pg_temp;

ALTER FUNCTION public.leave_public_match_atomic(UUID, UUID)
SET search_path = public, pg_temp;

ALTER FUNCTION public.cancel_booking_with_refund_atomic(UUID, UUID)
SET search_path = public, pg_temp;

ALTER FUNCTION public.close_owner_daily_shift(UUID, UUID, DATE)
SET search_path = public, pg_temp;

ALTER FUNCTION public.get_championship_standings(UUID, TEXT)
SET search_path = public, pg_temp;


-- 6. ⚡ HIGH-PERFORMANCE INDEXES (OPTIMIZED B-TREE & GIN)
-- ==============================================================================
-- A. حجوزات الملاعب والشفتات والبحث السريع
CREATE INDEX IF NOT EXISTS idx_bookings_owner_operational_date 
ON public.bookings (owner_id, operational_date);

CREATE INDEX IF NOT EXISTS idx_bookings_created_by_status 
ON public.bookings (created_by_user_id, status);

CREATE INDEX IF NOT EXISTS idx_bookings_stadium_time_active 
ON public.bookings (stadium_id, start_time, end_time) 
WHERE status != 'cancelled';

-- B. المحادثات والرسائل والإشعارات
CREATE INDEX IF NOT EXISTS idx_chat_messages_conv_created 
ON public.chat_messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
ON public.notifications (user_id, is_read, created_at DESC);

-- C. مباريات البطولات
CREATE INDEX IF NOT EXISTS idx_tournament_matches_champ_round 
ON public.tournament_matches (championship_id, round_index, match_index);

-- D. فهارس GIN للمصفوفات لسرعة التحقق الفائق من الصلاحيات
CREATE INDEX IF NOT EXISTS idx_conversations_participants_gin 
ON public.conversations USING GIN (participant_ids);

CREATE INDEX IF NOT EXISTS idx_bookings_joined_users_gin 
ON public.bookings USING GIN (joined_user_ids);

-- ==============================================================================
-- تم بحمد الله! السكريبت جاهز للتنفيذ الفوري في Supabase SQL Editor
-- ==============================================================================
