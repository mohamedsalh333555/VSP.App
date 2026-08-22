-- ============================================================================
-- 🛡️ VSP PRODUCTION DATABASE INTEGRITY & SECURITY UPGRADE
-- File: supabase/migrations/20260823_security_integrity_and_concurrency.sql
-- ============================================================================

-- 1️⃣ تأمين حقول جدول المستخدمين الحساسة (Users Table Field Protection Trigger)
CREATE OR REPLACE FUNCTION protect_user_sensitive_fields()
RETURNS TRIGGER AS $$
DECLARE
  v_caller_role text;
BEGIN
  -- السماح للـ Service Role والخادم الداخلي
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  -- استعلام عن رتبة المستخدم الذي يجري التعديل
  SELECT role INTO v_caller_role FROM users WHERE id = auth.uid();

  -- السماح الكامل للإدارة
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- حظر تعديل الرتبة وصلاحيات الحظر والاشتراكات من قِبل المستخدم العادي
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Security Alert: You cannot modify user role directly.';
  END IF;
  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
    RAISE EXCEPTION 'Security Alert: You cannot modify is_blocked status.';
  END IF;
  IF NEW.no_show_count IS DISTINCT FROM OLD.no_show_count THEN
    RAISE EXCEPTION 'Security Alert: You cannot modify no_show_count.';
  END IF;
  IF NEW.subscription_plan IS DISTINCT FROM OLD.subscription_plan THEN
    RAISE EXCEPTION 'Security Alert: You cannot modify subscription_plan directly.';
  END IF;
  IF NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at THEN
    RAISE EXCEPTION 'Security Alert: You cannot modify trial_ends_at directly.';
  END IF;
  IF NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at THEN
    RAISE EXCEPTION 'Security Alert: You cannot modify subscription_expires_at directly.';
  END IF;
  IF NEW.verification_status IS DISTINCT FROM OLD.verification_status AND NEW.verification_status = 'approved' THEN
    RAISE EXCEPTION 'Security Alert: Self-approving verification_status is prohibited.';
  END IF;
  IF NEW.is_identity_verified IS DISTINCT FROM OLD.is_identity_verified AND NEW.is_identity_verified = true THEN
    RAISE EXCEPTION 'Security Alert: Self-verifying identity is prohibited.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_user_sensitive_fields ON users;
CREATE TRIGGER trg_protect_user_sensitive_fields
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION protect_user_sensitive_fields();


-- 2️⃣ تأمين حقول جدول الملاعب الحساسة (Stadiums Field Protection Trigger)
CREATE OR REPLACE FUNCTION protect_stadium_sensitive_fields()
RETURNS TRIGGER AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- منع توثيق أو فك حظر الملعب ذاتياً
  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified AND NEW.is_verified = true THEN
    RAISE EXCEPTION 'Security Alert: Stadium verification requires admin approval.';
  END IF;
  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked AND NEW.is_blocked = false THEN
    RAISE EXCEPTION 'Security Alert: Stadium unblocking requires admin approval.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_stadium_sensitive_fields ON stadiums;
CREATE TRIGGER trg_protect_stadium_sensitive_fields
BEFORE UPDATE ON stadiums
FOR EACH ROW
EXECUTE FUNCTION protect_stadium_sensitive_fields();


-- 3️⃣ إزالة الفهارس المكررة لتسريع الأداء (Drop Duplicate Indexes)
DROP INDEX IF EXISTS idx_bookings_joined_users;
DROP INDEX IF EXISTS idx_conversations_participants;


-- 4️⃣ دالة ذرية آمنة لمغادرة المباريات العامة (Atomic Leave Match RPC)
CREATE OR REPLACE FUNCTION leave_public_match_atomic(p_booking_id uuid, p_user_id uuid)
RETURNS boolean AS $$
DECLARE
  v_booking bookings%ROWTYPE;
BEGIN
  -- قفل السجل ذرياً لمنع الـ Race Conditions
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF NOT (p_user_id = ANY(v_booking.joined_user_ids)) THEN
    RAISE EXCEPTION 'User is not a joined participant in this match';
  END IF;

  UPDATE bookings
  SET 
    current_players = GREATEST(0, current_players - 1),
    joined_user_ids = array_remove(joined_user_ids, p_user_id),
    updated_at = timezone('utc'::text, now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5️⃣ دالة ذرية آمنة لتعديل أماكن المستضيف (Atomic Host Spots Update RPC)
CREATE OR REPLACE FUNCTION update_host_spots_atomic(
  p_booking_id uuid,
  p_user_id uuid,
  p_new_host_spots integer
)
RETURNS boolean AS $$
DECLARE
  v_booking bookings%ROWTYPE;
  v_joined_count integer;
  v_capacity integer;
BEGIN
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF v_booking.created_by_user_id <> p_user_id AND v_booking.owner_id <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: Only the host or owner can modify spots';
  END IF;

  v_joined_count := coalesce(cardinality(v_booking.joined_user_ids), 0);
  v_capacity := coalesce(v_booking.total_field_capacity, 10);

  IF (v_joined_count + p_new_host_spots) > v_capacity THEN
    RAISE EXCEPTION 'Exceeds total stadium capacity';
  END IF;

  UPDATE bookings
  SET 
    current_players = v_joined_count + p_new_host_spots,
    updated_at = timezone('utc'::text, now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6️⃣ تصحيح وتأمين سياسات RLS لجدول الملاعب (Stadiums RLS Role Fix)
DROP POLICY IF EXISTS "stadiums_select_public" ON stadiums;
DROP POLICY IF EXISTS "stadiums_insert_own" ON stadiums;
DROP POLICY IF EXISTS "stadiums_update_own" ON stadiums;
DROP POLICY IF EXISTS "stadiums_delete_own" ON stadiums;

CREATE POLICY "stadiums_select_public" ON stadiums
FOR SELECT TO public
USING (((is_verified = true) AND (is_blocked = false) AND (is_deleted_by_owner = false)) OR (auth.uid() = owner_id));

CREATE POLICY "stadiums_insert_own" ON stadiums
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "stadiums_update_own" ON stadiums
FOR UPDATE TO authenticated
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "stadiums_delete_own" ON stadiums
FOR DELETE TO authenticated
USING (auth.uid() = owner_id);


-- 7️⃣ تأمين سياسات Storage Buckets الخاصة بالمستندات (Storage Security)
DO $$
BEGIN
  -- التأكد من سياسات الوصول لمجلد owner_documents
  IF EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'owner_documents') THEN
    DROP POLICY IF EXISTS "Owner upload own documents" ON storage.objects;
    DROP POLICY IF EXISTS "Owner access own documents or Admin" ON storage.objects;

    CREATE POLICY "Owner upload own documents" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'owner_documents' 
      AND (auth.uid())::text = (storage.foldername(name))[1]
    );

    CREATE POLICY "Owner access own documents or Admin" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'owner_documents' 
      AND (
        (auth.uid())::text = (storage.foldername(name))[1]
        OR EXISTS (
          SELECT 1 FROM users 
          WHERE users.id = auth.uid() 
          AND users.role IN ('admin', 'co_founder')
        )
      )
    );
  END IF;
END $$;
