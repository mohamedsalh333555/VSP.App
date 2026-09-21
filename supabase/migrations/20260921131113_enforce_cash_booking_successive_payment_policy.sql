-- Enforce the cash-booking succession policy at the database boundary.
-- A player cannot create another cash booking while an unpaid cash booking is still active.
-- A subsequent online booking is allowed, but any deposit requirement is forcibly removed,
-- making the payment full-online only.

CREATE OR REPLACE FUNCTION public.enforce_cash_booking_restrictions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_record record;
  v_active_cash_count integer := 0;
  v_booking_user_id uuid;
BEGIN
  -- Owner-created manual bookings for their own stadium are not player bookings.
  IF NEW.created_by_user_id IS NOT NULL
     AND NEW.owner_id IS NOT NULL
     AND NEW.created_by_user_id = NEW.owner_id THEN
    RETURN NEW;
  END IF;

  v_booking_user_id := COALESCE(NEW.created_by_user_id, NEW.user_id);

  IF v_booking_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Serialize booking creation for the same player so two concurrent requests
  -- cannot both pass the cash-policy check.
  PERFORM pg_advisory_xact_lock(
    hashtext('vsp_cash_booking_policy:' || v_booking_user_id::text)
  );

  SELECT
    is_blocked,
    COALESCE(no_show_count, 0) AS no_show_count
  INTO v_user_record
  FROM public.users
  WHERE id = v_booking_user_id;

  IF FOUND THEN
    IF v_user_record.is_blocked = true THEN
      RAISE EXCEPTION 'حسابك معلق حالياً من قبل الإدارة. لا يمكنك إجراء حجوزات جديدة.';
    END IF;

    IF NEW.payment_method = 'cash'
       AND v_user_record.no_show_count >= 2 THEN
      RAISE EXCEPTION 'حسابك مقيد مؤقتاً من الحجوزات النقدية بسبب تكرار عدم الحضور (No-Show). يرجى الدفع إلكترونياً لتأكيد الحجز.';
    END IF;
  END IF;

  -- Core business rule: an unpaid active cash booking blocks another cash booking.
  SELECT COUNT(*)
  INTO v_active_cash_count
  FROM public.bookings b
  WHERE (b.user_id = v_booking_user_id OR b.created_by_user_id = v_booking_user_id)
    AND b.payment_method = 'cash'
    AND COALESCE(b.is_paid, false) = false
    AND b.status IN ('pending', 'confirmed')
    AND b.end_time > now();

  IF v_active_cash_count > 0 THEN
    IF NEW.payment_method = 'cash' THEN
      RAISE EXCEPTION 'لديك حجز نقدي لم ينتهِ بعد. لا يمكن إنشاء حجز نقدي آخر قبل انتهاء الحجز السابق.';
    END IF;

    -- Any second online booking must be paid in full, never by deposit.
    IF NEW.payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
      NEW.needs_deposit := false;
      NEW.deposit_amount := 0;
      NEW.deposit_paid := 0;
      NEW.is_deposit_paid := false;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.enforce_cash_booking_restrictions() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_cash_booking_restrictions() FROM anon;
REVOKE ALL ON FUNCTION public.enforce_cash_booking_restrictions() FROM authenticated;
