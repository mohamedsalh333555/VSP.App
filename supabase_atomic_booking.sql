-- 🛡️ VSP Platform Audit Remediation: Atomic Booking & Security SQL Migration
-- 1. Atomic Booking Creation Function (Prevents Double-Booking via Row Locks)
CREATE OR REPLACE FUNCTION create_booking_atomic(
  p_stadium_id UUID,
  p_user_id UUID,
  p_owner_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_booking_type TEXT,
  p_total_price NUMERIC,
  p_stadium_name TEXT,
  p_stadium_image_url TEXT,
  p_is_private BOOLEAN DEFAULT TRUE,
  p_rent_ball BOOLEAN DEFAULT FALSE,
  p_needs_deposit BOOLEAN DEFAULT FALSE,
  p_deposit_amount NUMERIC DEFAULT 0,
  p_payment_method TEXT DEFAULT 'cash',
  p_payment_status TEXT DEFAULT 'unpaid',
  p_player_team_id UUID DEFAULT NULL,
  p_player_team_name TEXT DEFAULT NULL,
  p_opponent_team_id UUID DEFAULT NULL,
  p_opponent_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conflict_count INT;
  v_new_booking_id UUID;
  v_status TEXT;
  v_is_paid BOOLEAN;
  v_is_deposit_paid BOOLEAN;
BEGIN
  -- Perform an explicit row-level lock check on existing bookings for this stadium
  -- using FOR UPDATE to prevent race conditions during concurrent booking attempts.
  SELECT COUNT(*)
  INTO v_conflict_count
  FROM bookings
  WHERE stadium_id = p_stadium_id
    AND status NOT IN ('cancelled', 'rejected')
    AND (
      (p_start_time >= start_time AND p_start_time < end_time) OR
      (p_end_time > start_time AND p_end_time <= end_time) OR
      (p_start_time <= start_time AND p_end_time >= end_time)
    )
  FOR UPDATE;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'double_booking',
      'message', 'This time slot is already booked or currently being reserved by another player.'
    );
  END IF;

  -- Determine initial booking status & flags based on payment
  IF p_payment_status = 'paid' OR p_payment_method = 'free' THEN
    v_status := 'confirmed';
    v_is_paid := TRUE;
    v_is_deposit_paid := TRUE;
  ELSIF p_needs_deposit AND p_deposit_amount > 0 THEN
    v_status := 'pending';
    v_is_paid := FALSE;
    v_is_deposit_paid := FALSE;
  ELSE
    v_status := 'confirmed';
    v_is_paid := FALSE;
    v_is_deposit_paid := FALSE;
  END IF;

  -- Insert the booking atomically
  INSERT INTO bookings (
    stadium_id,
    user_id,
    owner_id,
    start_time,
    end_time,
    booking_type,
    total_price,
    stadium_name,
    stadium_image_url,
    is_private,
    rent_ball,
    needs_deposit,
    deposit_amount,
    payment_method,
    payment_status,
    status,
    is_paid,
    is_deposit_paid,
    player_team_id,
    player_team_name,
    opponent_team_id,
    opponent_team_name,
    created_at,
    updated_at
  )
  VALUES (
    p_stadium_id,
    p_user_id,
    p_owner_id,
    p_start_time,
    p_end_time,
    p_booking_type,
    p_total_price,
    p_stadium_name,
    p_stadium_image_url,
    p_is_private,
    p_rent_ball,
    p_needs_deposit,
    p_deposit_amount,
    p_payment_method,
    p_payment_status,
    v_status,
    v_is_paid,
    v_is_deposit_paid,
    p_player_team_id,
    p_player_team_name,
    p_opponent_team_id,
    p_opponent_team_name,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_new_booking_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'booking_id', v_new_booking_id,
    'status', v_status,
    'is_paid', v_is_paid
  );
END;
$$;

-- 2. Secure Owner Document Storage Bucket Policies (Private Bucket Access)
INSERT INTO storage.buckets (id, name, public)
VALUES ('owner_documents', 'owner_documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "Owners can upload their own docs" ON storage.objects;
CREATE POLICY "Owners can upload their own docs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'owner_documents' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Owners can view their own docs" ON storage.objects;
CREATE POLICY "Owners can view their own docs"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'owner_documents' AND auth.uid()::text = (storage.foldername(name))[1]);
