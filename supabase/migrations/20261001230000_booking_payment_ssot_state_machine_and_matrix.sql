-- Migration: 20261001230000_booking_payment_ssot_state_machine_and_matrix.sql
-- Description:
--   1. Enforce strict Whitelist Booking State Machine in public.bookings.
--   2. Expand bookings_payment_status_check to include 'fully_paid'.
--   3. Fix sync_payment_reconcile_state() trigger to enforce Booking x Payment Matrix, infer bank_transfer/unknown, and preserve refund states.
--   4. Update auto_expire_stale_records(), cleanup_stale_pending_bookings_atomic(), and cancel_expired_pending_bookings() to use status = 'expired', payment_status = 'unpaid'.
--   5. Fix cancel_booking_with_refund_atomic() to set payment_status = 'unpaid' on non-refunded cancellations.
--   6. Fix create_booking_atomic() and create_challenge_booking_atomic() cash rule to only block if previous active cash booking is unpaid (is_paid = false).
--   7. Record migration in supabase_migrations.schema_migrations.

-- 1. Expand bookings_payment_status_check constraint to include 'fully_paid'
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_payment_status_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_payment_status_check
  CHECK (payment_status = ANY (ARRAY[
    'pending'::text,
    'unpaid'::text,
    'paid'::text,
    'fully_paid'::text,
    'partially_paid'::text,
    'refunded'::text,
    'failed'::text,
    'refund_pending'::text,
    'refund_failed'::text
  ]));

-- 2. Strict Whitelist Booking State Machine Trigger Function
CREATE OR REPLACE FUNCTION public.trg_fn_enforce_booking_state_machine()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Explicit session override for rare administrative manual data repairs only
  IF current_setting('vsp.bypass_state_machine', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- If status is not changing, proceed
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- STRICT WHITELIST STATE MACHINE:
  -- Allowed transitions:
  --   pending   -> confirmed
  --   pending   -> cancelled
  --   pending   -> expired
  --   confirmed -> completed
  --   confirmed -> cancelled

  IF OLD.status = 'pending' AND NEW.status IN ('confirmed', 'cancelled', 'expired') THEN
    RETURN NEW;
  ELSIF OLD.status = 'confirmed' AND NEW.status IN ('completed', 'cancelled') THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'ILLEGAL_STATE_TRANSITION: Transition from % to % is strictly forbidden by SSOT state machine.', OLD.status, NEW.status
      USING ERRCODE = 'P0004', DETAIL = 'BOOKING_STATE_MACHINE_VIOLATION';
  END IF;

  RETURN NEW;
END;
$function$;

-- Ensure trigger is bound BEFORE UPDATE on public.bookings
DROP TRIGGER IF EXISTS aaa_trg_enforce_booking_state_machine ON public.bookings;
CREATE TRIGGER aaa_trg_enforce_booking_state_machine
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_enforce_booking_state_machine();

-- 3. Fix sync_payment_reconcile_state(): Payment Source + Refund Preservation + Payment Matrix Enforcement
CREATE OR REPLACE FUNCTION public.sync_payment_reconcile_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- 1. Infer payment source
  IF lower(coalesce(NEW.payment_method, '')) = 'cash'
     OR upper(coalesce(NEW.payment_transaction_id, '')) LIKE 'MANUAL%' THEN
    NEW.payment_source := 'cash';
  ELSIF lower(coalesce(NEW.payment_method, '')) IN ('paymob', 'card', 'online', 'wallet', 'visa', 'mastercard', 'meeza') THEN
    NEW.payment_source := 'paymob';
  ELSIF lower(coalesce(NEW.payment_method, '')) = 'instapay' THEN
    NEW.payment_source := 'instapay';
  ELSIF lower(coalesce(NEW.payment_method, '')) = 'vodafone_cash' THEN
    NEW.payment_source := 'vodafone_cash';
  ELSIF lower(coalesce(NEW.payment_method, '')) = 'bank_transfer' THEN
    NEW.payment_source := 'bank_transfer';
  ELSE
    NEW.payment_source := 'unknown';
  END IF;

  -- 2. Reconcile payment state hierarchy (strictly preserving refund states)
  IF NEW.payment_status = 'refunded' THEN
    NEW.payment_reconcile_state := 'refunded';
  ELSIF NEW.payment_status = 'refund_failed' THEN
    NEW.payment_reconcile_state := 'refund_failed';
  ELSIF NEW.payment_status = 'refund_pending' THEN
    NEW.payment_reconcile_state := 'refund_pending';
  ELSIF NEW.payment_reconcile_state IN ('refunded', 'refund_failed', 'refund_pending') THEN
    -- Preserve explicit reconcile refund state
    NULL;
  ELSIF NEW.is_paid = TRUE OR NEW.payment_status IN ('paid', 'fully_paid') OR NEW.payment_reconcile_state = 'fully_paid' THEN
    NEW.payment_reconcile_state := 'fully_paid';
  ELSIF (coalesce(NEW.deposit_paid, 0) > 0 AND NEW.deposit_paid < NEW.total_price)
     OR NEW.payment_status = 'partially_paid'
     OR NEW.payment_reconcile_state = 'partially_paid' THEN
    NEW.payment_reconcile_state := 'partially_paid';
  ELSE
    NEW.payment_reconcile_state := 'unpaid';
  END IF;

  -- 3. Payment Matrix Enforcement (enforced on INSERT or when status/payment changes)
  IF current_setting('vsp.bypass_state_machine', true) IS DISTINCT FROM 'true' THEN
    IF TG_OP = 'INSERT' OR (OLD.status IS DISTINCT FROM NEW.status OR OLD.payment_reconcile_state IS DISTINCT FROM NEW.payment_reconcile_state) THEN
      IF NEW.status = 'pending' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "pending" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'confirmed' THEN
        -- Cash bookings can be confirmed while unpaid (awaiting pitch payment)
        -- Online bookings (paymob, card, wallet, online) CANNOT be confirmed while unpaid
        IF NEW.payment_reconcile_state = 'unpaid' THEN
          IF NEW.payment_source = 'paymob' OR lower(coalesce(NEW.payment_method, '')) IN ('paymob', 'card', 'wallet', 'online', 'visa', 'mastercard', 'meeza') THEN
            RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: Online booking with payment method "%" cannot be confirmed while unpaid', NEW.payment_method
              USING ERRCODE = 'P0005', DETAIL = 'ONLINE_BOOKING_CANNOT_BE_CONFIRMED_UNPAID';
          END IF;
        ELSIF NEW.payment_reconcile_state NOT IN ('partially_paid', 'fully_paid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "confirmed" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'completed' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid', 'partially_paid', 'fully_paid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "completed" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'cancelled' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid', 'refund_pending', 'refunded', 'refund_failed') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "cancelled" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'expired' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "expired" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- 4. Expiration RPCs: Set status = 'expired', payment_status = 'unpaid'
CREATE OR REPLACE FUNCTION public.auto_expire_stale_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Stage 0: self-healing. A booking that was actually PAID but stayed stuck at 'pending'
  UPDATE public.bookings
  SET
    status = 'confirmed',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'confirmed' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-promoted to confirmed - payment succeeded but status was stuck at pending]'
  WHERE status = 'pending'
    AND (is_paid = TRUE OR payment_status IN ('paid', 'fully_paid', 'completed'))
    AND created_at <= NOW() - INTERVAL '2 minutes';

  -- Stage 1: expire bookings whose temporary payment lock elapsed
  UPDATE public.bookings
  SET
    status = 'expired',
    payment_status = 'unpaid',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'expired' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired - payment window elapsed]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'fully_paid', 'completed')
    AND locked_until IS NOT NULL
    AND locked_until < NOW();

  -- Stage 2: safety net - expire any unpaid pending older than 10 minutes
  UPDATE public.bookings
  SET
    status = 'expired',
    payment_status = 'unpaid',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'expired' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to payment timeout]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'fully_paid', 'completed')
    AND created_at <= NOW() - INTERVAL '10 minutes';

  -- Stage 3: expire stale challenge pending reservations
  UPDATE public.bookings
  SET
    status = 'expired',
    payment_status = 'unpaid',
    challenge_status = 'expired',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Challenge expired automatically]'
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND (
      NOW() - created_at >= INTERVAL '4 hours' OR
      start_time - NOW() <= INTERVAL '12 hours'
    );

  -- Stage 4: Expire stale team challenge codes (Automated 7-day lifecycle worker)
  UPDATE public.team_challenge_codes
  SET status = 'expired'
  WHERE status = 'active'
    AND expires_at IS NOT NULL
    AND expires_at < timezone('utc', now());
END;
$function$;

CREATE OR REPLACE FUNCTION public.cleanup_stale_pending_bookings_atomic(p_user_id uuid, p_stadium_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count integer;
BEGIN
  IF auth.uid() IS NULL OR (auth.uid() <> p_user_id AND coalesce((SELECT role FROM public.users WHERE id = auth.uid()), '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin')) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  UPDATE public.bookings
  SET status = 'expired',
      payment_status = 'unpaid',
      cancellation_reason = 'Payment checkout expired',
      updated_at = now()
  WHERE created_by_user_id = p_user_id
    AND stadium_id = p_stadium_id
    AND status = 'pending'
    AND created_at < now() - INTERVAL '10 minutes';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'cancelled_count', v_count);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_expired_pending_bookings()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cancelled_count int;
  v_now timestamptz := now();
BEGIN
  WITH expired_rows AS (
    UPDATE public.bookings
    SET
      status = 'expired',
      payment_status = 'unpaid',
      cancellation_reason = 'auto_expired_pending_payment',
      updated_at = v_now
    WHERE
      status = 'pending'
      AND payment_method IN ('paymob', 'card', 'wallet', 'online')
      AND is_paid = false
      AND coalesce(locked_until, created_at + INTERVAL '8 minutes') < v_now
    RETURNING id
  )
  SELECT count(*) INTO v_cancelled_count FROM expired_rows;

  RETURN jsonb_build_object(
    'success', true,
    'cancelled_count', v_cancelled_count,
    'ran_at', v_now
  );
END;
$function$;

-- 5. Cancellation RPC: set payment_status = 'unpaid' when no refund amount
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(p_booking_id uuid, p_reason text DEFAULT 'cancelled_by_user'::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking               record;
  v_refund_amount         numeric(10,2) := 0;
  v_refund_gross          numeric(10,2) := 0;
  v_tx_id                 uuid          := null;
  v_caller_role           text;
  v_minutes_since_created numeric;
  v_now                   timestamptz   := timezone('utc', now());
  v_paid_cash             numeric       := 0;
  v_total_gateway_paid    numeric       := 0;
  v_total_gross_paid      numeric       := 0;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_completed_booking', 'message', 'لا يمكن إلغاء حجز مكتمل.');
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', true, 'code', 'already_cancelled', 'already_cancelled', true,
      'booking_id', p_booking_id, 'refund_amount', coalesce(v_booking.refund_amount, 0));
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role' AND current_user NOT IN ('postgres', 'service_role') THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
    END IF;
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id
       AND auth.uid() IS DISTINCT FROM v_booking.user_id
       AND auth.uid() IS DISTINCT FROM v_booking.owner_id
       AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: لا يمكنك إلغاء هذا الحجز.');
    END IF;
    IF auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id THEN
      v_minutes_since_created := extract(epoch FROM (v_now - coalesce(v_booking.created_at, v_now))) / 60.0;
      IF v_minutes_since_created > (SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id = 1)
         AND v_booking.start_time <= (v_now + ((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id = 1) * interval '1 hour'))
      THEN
        RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_within_6_hours',
          'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات إلا خلال أول 20 دقيقة.');
      END IF;
    END IF;
  END IF;

  IF lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN
    SELECT coalesce(sum(CASE WHEN t.type = 'refund_cash' THEN -abs(t.amount) ELSE abs(t.amount) END), 0)
    INTO v_paid_cash
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.payment_method = 'cash'
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit', 'cash_settlement', 'cash_collection_adjustment', 'refund_cash');
    v_refund_amount := round(greatest(v_paid_cash, 0), 2);
    v_refund_gross  := v_refund_amount;
  ELSE
    SELECT
      coalesce(sum(t.amount), 0),
      coalesce(sum(coalesce(t.gross_amount, t.amount)), 0)
    INTO v_total_gateway_paid, v_total_gross_paid
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status = 'completed'
      AND t.type IN ('payment', 'deposit')
      AND lower(coalesce(t.payment_method, '')) <> 'cash';

    SELECT round(greatest(v_total_gateway_paid - coalesce(sum(t.amount), 0), 0), 2)
    INTO v_refund_amount
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    SELECT round(greatest(v_total_gross_paid - coalesce(sum(coalesce(t.gross_amount, t.amount)), 0), 0), 2)
    INTO v_refund_gross
    FROM public.transactions t
    WHERE t.booking_id = p_booking_id
      AND t.status IN ('completed', 'pending')
      AND t.type IN ('refund', 'refund_card', 'refund_wallet', 'refund_pending');

    v_refund_amount := coalesce(v_refund_amount, 0);
    v_refund_gross  := coalesce(v_refund_gross,  0);
  END IF;

  UPDATE public.bookings SET
    status              = 'cancelled',
    is_paid             = false,
    payment_status      = CASE
                            WHEN v_refund_amount > 0 AND lower(coalesce(payment_method, '')) <> 'cash' THEN 'refund_pending'
                            WHEN v_refund_amount > 0                                                   THEN 'refunded'
                            ELSE 'unpaid'
                          END,
    refund_amount       = CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE refund_amount END,
    cancellation_reason = p_reason,
    cancelled_at        = v_now,
    updated_at          = v_now
  WHERE id = p_booking_id;

  IF v_refund_amount > 0
     AND NOT EXISTS (
       SELECT 1 FROM public.transactions
       WHERE booking_id = p_booking_id
         AND type IN ('refund', 'refund_card', 'refund_wallet', 'refund_cash', 'refund_pending')
         AND status IN ('pending', 'completed')
     ) THEN
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(v_booking.created_by_user_id, v_booking.user_id),
      p_booking_id,
      v_refund_amount,
      v_refund_gross,
      'refund',
      CASE WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'completed' ELSE 'pending' END,
      coalesce(v_booking.payment_method, 'online'),
      CASE
        WHEN lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN 'استرداد نقدي بالملعب لإلغاء الحجز'
        ELSE 'طلب استرداد إلكتروني قيد المعالجة'
      END,
      jsonb_build_object(
        'refund_principal', v_refund_amount,
        'refund_gross',     v_refund_gross,
        'source',           'cancel_booking_with_refund_atomic',
        'cancelled_at',     v_now
      ),
      v_now, v_now
    ) RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success',        true,
    'message',        'تم إلغاء الحجز بنجاح.',
    'refund_amount',  v_refund_amount,
    'refund_gross',   v_refund_gross,
    'payment_status', CASE
                        WHEN v_refund_amount > 0 AND lower(coalesce(v_booking.payment_method, '')) <> 'cash' THEN 'refund_pending'
                        WHEN v_refund_amount > 0 THEN 'refunded'
                        ELSE 'unpaid'
                      END,
    'booking_id',     p_booking_id,
    'transaction_id', v_tx_id
  );
END;
$function$;

-- 6. Cash Rule RPC updates (is_paid = false check)
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
  p_stadium_id text,
  p_user_id text,
  p_owner_id text,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_booking_type text,
  p_total_price numeric,
  p_stadium_name text DEFAULT ''::text,
  p_stadium_image_url text DEFAULT ''::text,
  p_is_private boolean DEFAULT true,
  p_rent_ball boolean DEFAULT false,
  p_needs_deposit boolean DEFAULT false,
  p_deposit_amount numeric DEFAULT 0,
  p_payment_method text DEFAULT 'cash'::text,
  p_payment_status text DEFAULT 'pending'::text,
  p_player_team_id text DEFAULT NULL::text,
  p_player_team_name text DEFAULT NULL::text,
  p_opponent_team_id text DEFAULT NULL::text,
  p_opponent_team_name text DEFAULT NULL::text,
  p_platform_fee numeric DEFAULT 0,
  p_idempotency_key text DEFAULT NULL::text,
  p_initial_players integer DEFAULT 1,
  p_total_capacity integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium record; v_caller uuid := auth.uid(); v_caller_role text;
  v_duration_hours numeric; v_calculated_price numeric; v_hourly_rate numeric;
  v_ball_price numeric := 0; v_final_total_price numeric;
  v_final_needs_deposit boolean; v_final_deposit_amount numeric; v_final_deposit_paid numeric := 0;
  v_final_status text; v_final_is_paid boolean; v_locked_until timestamptz;
  v_active_cash_count int := 0; v_conflict_count int := 0;
  v_user_blocked boolean; v_no_show_count int;
  v_new_booking_id uuid; v_existing_id uuid; v_existing_status text;
  v_now timestamptz := timezone('utc', now());
  v_initial_players int; v_capacity int; v_raw_type text; v_normalized_type text;
BEGIN
  v_raw_type := lower(trim(COALESCE(p_booking_type,'')));
  IF v_raw_type='openjoin' THEN v_raw_type:='open_join'; END IF;
  IF v_raw_type NOT IN ('personal','open_join','challenge') THEN
    RETURN jsonb_build_object('success',false,'code','INVALID_BOOKING_TYPE','message','نوع الحجز غير صالح.');
  END IF;
  IF v_raw_type='challenge' THEN
    RETURN jsonb_build_object('success',false,'code','USE_CHALLENGE_RPC','message','حجوزات التحدي تتم عبر create_challenge_booking_atomic فقط.');
  END IF;
  v_normalized_type:=v_raw_type;
  IF v_caller IS NULL AND current_user NOT IN ('postgres','service_role') THEN
    RETURN jsonb_build_object('success',false,'message','يجب تسجيل الدخول أولاً.');
  END IF;
  IF v_caller IS NOT NULL THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id=v_caller;
    IF v_caller::text<>p_user_id AND COALESCE(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') AND current_user NOT IN ('postgres','service_role') THEN
      RETURN jsonb_build_object('success',false,'message','غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
    END IF;
  END IF;
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id,status INTO v_existing_id,v_existing_status FROM public.bookings WHERE idempotency_key=p_idempotency_key AND status<>'cancelled' LIMIT 1;
    IF FOUND THEN RETURN jsonb_build_object('success',true,'booking_id',v_existing_id,'status',v_existing_status,'idempotent',true); END IF;
  END IF;
  v_duration_hours:=EXTRACT(EPOCH FROM(p_end_time-p_start_time))/3600.0;
  IF v_duration_hours<=0 THEN RETURN jsonb_build_object('success',false,'message','وقت بداية ونهاية الحجز غير صالح.'); END IF;
  IF v_duration_hours<((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id=1)/60.0) OR v_duration_hours>(SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id=1) THEN
    RETURN jsonb_build_object('success',false,'message','مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id,0));
  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text=p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الملعب المطلوب غير موجود.'); END IF;
  IF v_stadium.is_deleted_by_owner THEN RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب محذوف.'); END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب غير متاح للحجز حالياً.'); END IF;
  SELECT is_blocked,COALESCE(no_show_count,0) INTO v_user_blocked,v_no_show_count FROM public.users WHERE id::text=p_user_id;
  IF COALESCE(v_user_blocked,false) THEN RETURN jsonb_build_object('success',false,'message','حسابك مقيد حالياً.'); END IF;
  IF lower(COALESCE(p_payment_method,''))='cash' AND v_no_show_count>=(SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id=1) THEN
    RETURN jsonb_build_object('success',false,'message','حسابك مقيد عن الحجز النقدي.');
  END IF;

  -- Cash policy: Only UNPAID active cash bookings block a new cash booking
  SELECT COUNT(*) INTO v_active_cash_count FROM public.bookings 
  WHERE (user_id::text=p_user_id OR created_by_user_id::text=p_user_id) 
    AND lower(COALESCE(payment_method,''))='cash' 
    AND status IN('pending','confirmed') 
    AND COALESCE(is_paid, false) = false
    AND end_time>v_now;

  IF lower(COALESCE(p_payment_method,''))='cash' AND v_active_cash_count>0 THEN
    RETURN jsonb_build_object('success',false,'code','ACTIVE_CASH_BOOKING_EXISTS','requires_full_online',true,'message','لديك حجز نقدي غير مسدد قائم بالفعل. يرجى سداده أولاً أو الدفع إلكترونياً.');
  END IF;

  v_final_needs_deposit:=COALESCE(v_stadium.needs_deposit,false);
  v_final_deposit_amount:=CASE WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount,0) ELSE 0 END;
  v_hourly_rate:=COALESCE(v_stadium.price_per_hour,v_stadium.base_price,0);
  v_calculated_price:=ROUND(v_hourly_rate*v_duration_hours,2);
  IF p_rent_ball THEN
    BEGIN v_ball_price:=COALESCE((v_stadium.features->>'ballPrice')::numeric,0);
    EXCEPTION WHEN OTHERS THEN v_ball_price:=0; END;
    v_calculated_price:=v_calculated_price+v_ball_price;
  END IF;
  IF v_calculated_price<=0 THEN RETURN jsonb_build_object('success',false,'message','تسعيرة الملعب غير صحيحة.'); END IF;
  v_final_total_price:=v_calculated_price;
  IF lower(COALESCE(p_payment_method,'')) IN ('paymob','card','wallet','online') THEN
    v_final_status:='pending'; v_final_is_paid:=false;
    v_locked_until:=v_now+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval;
  ELSE
    v_final_status:='confirmed'; v_final_is_paid:=false; v_locked_until:=NULL;
  END IF;
  SELECT COUNT(*) INTO v_conflict_count FROM public.bookings WHERE stadium_id::text=p_stadium_id AND status<>'cancelled'
    AND NOT(status='pending' AND COALESCE(locked_until,created_at+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval)<v_now)
    AND p_start_time<end_time AND p_end_time>start_time;
  IF v_conflict_count>0 THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، هذا الموعد محجوز أو قيد الدفع من لاعب آخر حالياً.');
  END IF;

  IF v_normalized_type='open_join' THEN
    v_initial_players:=COALESCE(p_initial_players,1);
    IF v_initial_players<1 THEN
      RETURN jsonb_build_object('success',false,'code','INVALID_INITIAL_PLAYERS','message','عدد اللاعبين المبدئي يجب أن يكون 1 على الأقل.');
    END IF;
    v_capacity:=v_stadium.total_field_capacity;
    IF v_capacity IS NULL OR v_capacity<1 THEN
      RETURN jsonb_build_object('success',false,'code','STADIUM_CAPACITY_NOT_CONFIGURED',
        'message','هذا الملعب لا تتوفر له سعة محددة. لا يمكن إنشاء حجز مفتوح حتى يقوم المالك بتحديد السعة.');
    END IF;
    IF v_initial_players>v_capacity THEN
      RETURN jsonb_build_object('success',false,'code','INITIAL_PLAYERS_EXCEED_CAPACITY',
        'message','عدد اللاعبين المبدئي ('||v_initial_players||') لا يمكن أن يتجاوز سعة الملعب ('||v_capacity||').');
    END IF;
  ELSE
    v_initial_players:=1; v_capacity:=NULL;
  END IF;
  INSERT INTO public.bookings(
    stadium_id,user_id,created_by_user_id,owner_id,
    start_time,end_time,booking_type,total_price,vsp_commission,gateway_fee,platform_fee,
    stadium_name,stadium_image_url,is_private,rent_ball,
    needs_deposit,deposit_amount,deposit_paid,
    payment_method,payment_status,status,is_paid,
    player_team_id,player_team_name,opponent_team_id,opponent_team_name,challenge_status,
    joined_user_ids,current_players,initial_players_count,total_field_capacity,
    locked_until,idempotency_key,created_at,updated_at
  ) VALUES(
    p_stadium_id::uuid,p_user_id::uuid,p_user_id::uuid,v_stadium.owner_id,
    p_start_time,p_end_time,v_normalized_type,
    v_final_total_price,0,0,0,
    v_stadium.name,v_stadium.image_url,p_is_private,p_rent_ball,
    v_final_needs_deposit,v_final_deposit_amount,v_final_deposit_paid,
    lower(COALESCE(p_payment_method,'cash')),'pending',v_final_status,v_final_is_paid,
    CASE WHEN p_player_team_id~'^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
    p_player_team_name,
    CASE WHEN p_opponent_team_id~'^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
    p_opponent_team_name,NULL,
    ARRAY[p_user_id::uuid],v_initial_players,v_initial_players,v_capacity,
    v_locked_until,p_idempotency_key,v_now,v_now
  ) RETURNING id INTO v_new_booking_id;
  RETURN jsonb_build_object(
    'success',true,'booking_id',v_new_booking_id,'status',v_final_status,
    'total_price',v_final_total_price,'needs_deposit',v_final_needs_deposit,
    'deposit_amount',v_final_deposit_amount,'initial_players',v_initial_players,
    'total_capacity',v_capacity,
    'requires_full_online',(v_active_cash_count>0 AND lower(COALESCE(p_payment_method,'')) IN ('paymob','card','wallet','online')),
    'locked_until',v_locked_until
  );
EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_challenge_booking_atomic(
  p_challenge_code text,
  p_stadium_id text,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_payment_method text DEFAULT 'cash'::text,
  p_rent_ball boolean DEFAULT false,
  p_idempotency_key text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller                 uuid := auth.uid();
  v_caller_role            text;
  v_caller_team            record;
  v_code_entry             record;
  v_opponent_team          record;
  v_stadium                record;
  v_duration_hours         numeric;
  v_hourly_rate            numeric;
  v_price                  numeric;
  v_ball_price             numeric := 0;
  v_final_status           text;
  v_final_challenge_status text;
  v_final_is_paid          boolean;
  v_locked_until           timestamptz;
  v_conflict_count         int;
  v_active_cash_cnt        int := 0;
  v_user_blocked           boolean;
  v_no_show_count          int;
  v_new_booking_id         uuid;
  v_new_code               text;
  v_new_code_id            uuid;
  v_existing_id            uuid;
  v_existing_status        text;
  v_existing_user_id       uuid;
  v_clean_code             text;
  v_now                    timestamptz := timezone('utc', now());
BEGIN
  -- 1. Authentication check
  IF v_caller IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED',
      'message', 'يجب تسجيل الدخول أولاً.');
  END IF;

  -- 2. Strengthened User-Scoped Idempotency protection
  IF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT id, status, user_id INTO v_existing_id, v_existing_status, v_existing_user_id
    FROM public.bookings
    WHERE idempotency_key = trim(p_idempotency_key) AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      IF v_existing_user_id IS NOT NULL AND v_caller IS NOT NULL AND v_existing_user_id <> v_caller THEN
        RETURN jsonb_build_object(
          'success', false,
          'error',   'IDEMPOTENCY_KEY_COLLISION',
          'message', 'مفتاح العملية غير صالح أو مستخدم مسبقاً لحساب آخر.'
        );
      END IF;

      RETURN jsonb_build_object(
        'success',     true,
        'booking_id',  v_existing_id,
        'status',      v_existing_status,
        'idempotent',  true
      );
    END IF;
  END IF;

  -- Normalize challenge code (strip 'VSP-' prefix if provided)
  v_clean_code := upper(trim(COALESCE(p_challenge_code, '')));
  IF v_clean_code LIKE 'VSP-%' THEN
    v_clean_code := substring(v_clean_code from 5);
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_CHALLENGE_CODE',
      'message', 'يرجى إدخال كود التحدي.');
  END IF;

  -- 3. Verify caller is a captain of an active team
  SELECT t.* INTO v_caller_team 
  FROM public.teams t 
  WHERE t.captain_id = v_caller 
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN',
      'message', 'يجب أن تكون كابتن فريق لإنشاء حجز تحدي.');
  END IF;

  -- 4. Verify & lock challenge code (match either raw code or with prefix)
  SELECT * INTO v_code_entry
  FROM public.team_challenge_codes
  WHERE (code = v_clean_code OR code = 'VSP-' || v_clean_code) AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_INVALID_OR_USED',
      'message', 'كود التحدي غير صالح أو تم استخدامه مسبقاً.');
  END IF;

  IF v_code_entry.expires_at IS NOT NULL AND v_code_entry.expires_at < v_now THEN
    UPDATE public.team_challenge_codes SET status = 'expired' WHERE id = v_code_entry.id;
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_EXPIRED',
      'message', 'كود التحدي منتهي الصلاحية.');
  END IF;

  -- 5. Opponent team validation & Server-Side Eligibility
  SELECT * INTO v_opponent_team FROM public.teams WHERE id = v_code_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_NOT_FOUND',
      'message', 'تعذر العثور على الفريق صاحب الكود.');
  END IF;

  IF v_caller_team.id = v_opponent_team.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM',
      'message', 'لا يمكنك تحدي فريقك نفسه.');
  END IF;

  -- Server-Side FairPlay Eligibility (attendance_score >= 40)
  IF COALESCE(v_caller_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'فريقك مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  IF COALESCE(v_opponent_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'الفريق المنافس مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  -- 6. Platform business rules: Duration check
  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TIME_RANGE',
      'message', 'وقت بداية ونهاية الحجز غير صالح.');
  END IF;
  IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id = 1) / 60.0)
     OR v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DURATION',
      'message', 'مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  -- 7. Advisory lock per stadium to serialize slot bookings
  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

  -- 8. Validate stadium
  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_NOT_FOUND',
      'message', 'الملعب المطلوب غير موجود.');
  END IF;
  IF COALESCE(v_stadium.is_deleted_by_owner, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_DELETED',
      'message', 'عذراً، هذا الملعب محذوف.');
  END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE',
      'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;

  -- 9. User Account & Cash Rules (Same SSOT as create_booking_atomic)
  SELECT is_blocked, COALESCE(no_show_count, 0)
  INTO v_user_blocked, v_no_show_count
  FROM public.users WHERE id = v_caller;
  IF COALESCE(v_user_blocked, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_BLOCKED',
      'message', 'حسابك مقيد حالياً.');
  END IF;

  IF lower(COALESCE(p_payment_method, 'cash')) = 'cash'
     AND v_no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'CASH_LIMIT_EXCEEDED',
      'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
  END IF;

  -- Cash policy: Only UNPAID active cash bookings block a new cash booking
  SELECT COUNT(*) INTO v_active_cash_cnt
  FROM public.bookings
  WHERE (user_id = v_caller OR created_by_user_id = v_caller)
    AND lower(COALESCE(payment_method, '')) = 'cash'
    AND status IN ('pending', 'confirmed') 
    AND COALESCE(is_paid, false) = false
    AND end_time > v_now;

  IF lower(COALESCE(p_payment_method, 'cash')) = 'cash' AND v_active_cash_cnt > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online', true,
      'message', 'لديك حجز نقدي غير مسدد قائم بالفعل. يرجى سداده أولاً أو الدفع إلكترونياً.');
  END IF;

  -- 10. Authoritative Server-Side Pricing
  v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
  v_price := ROUND(v_hourly_rate * v_duration_hours, 2);
  IF p_rent_ball THEN
    BEGIN v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0);
    EXCEPTION WHEN OTHERS THEN v_ball_price := 0; END;
    v_price := v_price + v_ball_price;
  END IF;
  IF v_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_PRICE_NOT_SET',
      'message', 'تسعيرة الملعب غير صحيحة.');
  END IF;

  -- 11. Slot conflict check
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text = p_stadium_id AND status <> 'cancelled'
    AND NOT (status = 'pending'
      AND COALESCE(locked_until, created_at + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval) < v_now)
    AND p_start_time < end_time AND p_end_time > start_time;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع حالياً.');
  END IF;

  -- 12. Status and Payment Lock Window: Perfect SSOT State Alignment
  IF lower(COALESCE(p_payment_method, 'cash')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status           := 'pending';
    v_final_challenge_status := 'ready';       -- Ready, awaiting payment confirmation
    v_final_is_paid          := false;
    v_locked_until           := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval;
  ELSE
    v_final_status           := 'confirmed';
    v_final_challenge_status := 'confirmed';   -- Confirmed immediately for cash
    v_final_is_paid          := false;
    v_locked_until           := NULL;
  END IF;

  -- 13. Insert Booking (Player counters are strictly NULL for Challenge matches)
  INSERT INTO public.bookings (
    stadium_id, user_id, created_by_user_id, owner_id,
    start_time, end_time, booking_type,
    total_price, platform_fee, vsp_commission, gateway_fee,
    stadium_name, stadium_image_url,
    is_private, rent_ball,
    needs_deposit, deposit_amount, deposit_paid,
    payment_method, payment_status, status, is_paid,
    player_team_id, player_team_name,
    opponent_team_id, opponent_team_name,
    challenge_status,
    joined_user_ids, current_players, initial_players_count, total_field_capacity,
    locked_until, idempotency_key,
    created_at, updated_at
  ) VALUES (
    p_stadium_id::uuid, v_caller, v_caller, v_stadium.owner_id,
    p_start_time, p_end_time, 'challenge',
    v_price, 0, 0, 0,
    v_stadium.name, v_stadium.image_url,
    true, p_rent_ball,
    COALESCE(v_stadium.needs_deposit, false),
    CASE WHEN COALESCE(v_stadium.needs_deposit, false) THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END,
    0,
    lower(COALESCE(p_payment_method, 'cash')), 'pending',
    v_final_status, v_final_is_paid,
    v_caller_team.id, v_caller_team.name,
    v_opponent_team.id, v_opponent_team.name,
    v_final_challenge_status,
    ARRAY[v_caller], NULL, NULL, NULL,
    v_locked_until, p_idempotency_key,
    v_now, v_now
  )
  RETURNING id INTO v_new_booking_id;

  -- 14. Consume challenge code
  UPDATE public.team_challenge_codes
  SET status = 'used', used_at = v_now, used_in_booking_id = v_new_booking_id
  WHERE id = v_code_entry.id;

  -- 15. Generate fresh replacement challenge code for opponent team with 7-day expiration
  v_new_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at, expires_at)
  VALUES (v_opponent_team.id, v_new_code, 'active', v_now, v_now + INTERVAL '7 days')
  RETURNING id INTO v_new_code_id;

  RETURN jsonb_build_object(
    'success',            true,
    'booking_id',         v_new_booking_id,
    'status',             v_final_status,
    'challenge_status',   v_final_challenge_status,
    'total_price',        v_price,
    'player_team_id',     v_caller_team.id,
    'player_team_name',   v_caller_team.name,
    'opponent_team_id',   v_opponent_team.id,
    'opponent_team_name', v_opponent_team.name,
    'new_opponent_code',  v_new_code,
    'locked_until',       v_locked_until
  );

EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$;

-- 7. Record migration in schema_migrations
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261001230000', 'booking_payment_ssot_state_machine_and_matrix')
ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name;
