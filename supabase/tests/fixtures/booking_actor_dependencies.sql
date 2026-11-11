-- ISOLATED TEST FIXTURE ONLY: observed schema defaults/indexes and existing RPC bodies.

CREATE TABLE public.player_trophies ("id" uuid DEFAULT gen_random_uuid() NOT NULL,
"user_id" uuid,
"championship_id" uuid,
"title" text NOT NULL,
"prize_won" numeric DEFAULT 0,
"created_at" timestamp with time zone DEFAULT now(),
"tournament_1v1_id" uuid);

ALTER TABLE public."payout_settlements" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE public."payout_settlements" ALTER COLUMN "id" SET NOT NULL;

ALTER TABLE public."payout_settlements" ALTER COLUMN "amount" SET NOT NULL;

ALTER TABLE public."payout_settlements" ALTER COLUMN "method" SET NOT NULL;

ALTER TABLE public."payout_settlements" ALTER COLUMN "destination" SET NOT NULL;

ALTER TABLE public."payout_settlements" ALTER COLUMN "status" SET DEFAULT 'pending'::text;

ALTER TABLE public."payout_settlements" ALTER COLUMN "status" SET NOT NULL;

ALTER TABLE public."payout_settlements" ALTER COLUMN "created_at" SET DEFAULT timezone('utc'::text, now());

ALTER TABLE public."payout_settlements" ALTER COLUMN "created_at" SET NOT NULL;

ALTER TABLE public."payout_settlements" ALTER COLUMN "updated_at" SET DEFAULT timezone('utc'::text, now());

ALTER TABLE public."payout_settlements" ALTER COLUMN "updated_at" SET NOT NULL;

ALTER TABLE public."transactions" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE public."transactions" ALTER COLUMN "id" SET NOT NULL;

ALTER TABLE public."transactions" ALTER COLUMN "type" SET NOT NULL;

ALTER TABLE public."transactions" ALTER COLUMN "amount" SET NOT NULL;

ALTER TABLE public."transactions" ALTER COLUMN "created_at" SET DEFAULT timezone('utc'::text, now());

ALTER TABLE public."transactions" ALTER COLUMN "created_at" SET NOT NULL;

ALTER TABLE public."transactions" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE public."transactions" ALTER COLUMN "status" SET DEFAULT 'pending'::text;

ALTER TABLE public."transactions" ALTER COLUMN "status" SET NOT NULL;

ALTER TABLE public."transactions" ALTER COLUMN "updated_at" SET DEFAULT timezone('utc'::text, now());

ALTER TABLE public."transactions" ALTER COLUMN "updated_at" SET NOT NULL;

CREATE UNIQUE INDEX payout_settlements_pkey ON public.payout_settlements USING btree (id);

CREATE UNIQUE INDEX transactions_pkey ON public.transactions USING btree (id);

CREATE UNIQUE INDEX ux_transactions_paymob_transaction_id ON public.transactions USING btree (paymob_transaction_id) WHERE ((paymob_transaction_id IS NOT NULL) AND (btrim(paymob_transaction_id) <> ''::text));

CREATE UNIQUE INDEX idx_transactions_unique_cash_settlement ON public.transactions USING btree (booking_id) WHERE ((type = 'cash_settlement'::text) AND (status = 'completed'::text));

CREATE UNIQUE INDEX idx_transactions_unique_booking_refund ON public.transactions USING btree (booking_id) WHERE ((type = ANY (ARRAY['refund'::text, 'refund_card'::text, 'refund_wallet'::text, 'refund_cash'::text, 'refund_pending'::text])) AND (status = ANY (ARRAY['completed'::text, 'pending'::text])));

CREATE OR REPLACE FUNCTION public.vsp_validate_stadium_booking_window(p_opening_time time without time zone, p_closing_time time without time zone, p_break_start_time time without time zone, p_break_end_time time without time zone, p_is_split_shift boolean, p_maintenance_until timestamp with time zone, p_start_time timestamp with time zone, p_end_time timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_local_start timestamp;
  v_local_end timestamp;
  v_day date;
  v_open_ts timestamp;
  v_close_ts timestamp;
  v_break_start_ts timestamp;
  v_break_end_ts timestamp;
begin
  if p_end_time <= p_start_time then return false; end if;
  if p_maintenance_until is not null and p_end_time > p_maintenance_until then return false; end if;

  v_local_start := timezone('Africa/Cairo', p_start_time);
  v_local_end := timezone('Africa/Cairo', p_end_time);
  v_day := v_local_start::date;

  if p_opening_time is null or p_closing_time is null then return false; end if;

  v_open_ts := v_day + p_opening_time;
  v_close_ts := v_day + p_closing_time;

  if p_closing_time <= p_opening_time then
    v_close_ts := v_close_ts + interval '1 day';
    if v_local_start < v_open_ts then
      v_open_ts := v_open_ts - interval '1 day';
      v_close_ts := v_close_ts - interval '1 day';
    end if;
  end if;

  if v_local_start < v_open_ts or v_local_end > v_close_ts then return false; end if;

  if coalesce(p_is_split_shift,false)
     and p_break_start_time is not null
     and p_break_end_time is not null
     and p_break_start_time <> p_break_end_time then
    v_break_start_ts := v_day + p_break_start_time;
    v_break_end_ts := v_day + p_break_end_time;

    if p_break_end_time <= p_break_start_time then
      v_break_end_ts := v_break_end_ts + interval '1 day';
      if v_local_start < v_break_start_ts then
        v_break_start_ts := v_break_start_ts - interval '1 day';
        v_break_end_ts := v_break_end_ts - interval '1 day';
      end if;
    end if;

    if v_local_start < v_break_end_ts and v_local_end > v_break_start_ts then
      return false;
    end if;
  end if;

  return true;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_1v1_tournament_with_refund_requests(p_tournament_id uuid, p_reason text DEFAULT 'إلغاء البطولة'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_t RECORD;
  v_rec RECORD;
  v_count INT := 0;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_refund_amt NUMERIC;
  v_is_manual_review BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN 
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول'); 
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_uid;
  IF v_role NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: صلاحية الإلغاء للأدمن فقط');
  END IF;

  SELECT * INTO v_t FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN 
    RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة'); 
  END IF;
  
  IF v_t.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكن إلغاء بطولة منتهية أو ملغاة بالفعل');
  END IF;

  -- Process refund queue items for all paid players strictly using historical gross_amount
  FOR v_rec IN 
    SELECT * FROM public.vsp_1v1_tournament_orders
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid'
  LOOP
    v_count := v_count + 1;
    
    -- 🛡️ Gate 8 Rule: Automated refund strictly uses gross_amount. If NULL/<=0 -> manual review, NO fallback to base amount
    IF v_rec.gross_amount IS NULL OR v_rec.gross_amount <= 0
       OR v_rec.amount IS NULL OR v_rec.amount <= 0
       OR nullif(trim(v_rec.paymob_transaction_id),'') IS NULL THEN
      v_is_manual_review := TRUE;
      v_refund_amt := v_rec.amount; -- Keep base amount recorded for manual review reference

      UPDATE public.vsp_1v1_tournament_orders
      SET payment_status = 'refund_failed_manual_review',
          updated_at = v_now
      WHERE id = v_rec.id;

      INSERT INTO public.vsp_1v1_cancellation_refund_queue (
        tournament_id,
        order_id,
        user_id,
        paymob_transaction_id,
        amount,
        status,
        failure_reason,
        created_at,
        updated_at
      ) VALUES (
        p_tournament_id,
        v_rec.id,
        v_rec.user_id,
        v_rec.paymob_transaction_id,
        v_refund_amt,
        'failed_manual_review',
        'Missing historical gross_amount; manual refund review required',
        v_now,
        v_now
      );

      INSERT INTO public.transactions (
        user_id, amount, type, status, 
        payment_method, reference_number, paymob_transaction_id,
        metadata, description, created_at, updated_at
      ) VALUES (
        v_rec.user_id, v_refund_amt, 'refund_request', 'manual_review',
        'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
        jsonb_build_object(
          'order_reference', v_rec.order_reference,
          'paymob_transaction_id', v_rec.paymob_transaction_id,
          'tournament_id', p_tournament_id,
          'tournament_name', v_t.name,
          'principal_amount', v_rec.amount,
          'gross_amount', null,
          'requires_manual_review', true,
          'reason', coalesce(p_reason, 'إلغاء البطولة')
        ),
        'طلب استرداد رسوم بطولة 1v1 يتطلب مراجعة يدوية لغياب المبلغ التاريخي الإجمالي',
        v_now, v_now
      );

    ELSE
      v_is_manual_review := FALSE;
      v_refund_amt := round(v_rec.amount,2);

      UPDATE public.vsp_1v1_tournament_orders
      SET payment_status = 'refund_requested',
          updated_at = v_now
      WHERE id = v_rec.id;

      INSERT INTO public.vsp_1v1_cancellation_refund_queue (
        tournament_id,
        order_id,
        user_id,
        paymob_transaction_id,
        amount,
        status,
        created_at,
        updated_at
      ) VALUES (
        p_tournament_id,
        v_rec.id,
        v_rec.user_id,
        v_rec.paymob_transaction_id,
        v_refund_amt,
        'pending',
        v_now,
        v_now
      );

      INSERT INTO public.transactions (
        user_id, amount, type, status, 
        payment_method, reference_number, paymob_transaction_id,
        metadata, description, created_at, updated_at
      ) VALUES (
        v_rec.user_id, v_refund_amt, 'refund_request', 'pending',
        'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
        jsonb_build_object(
          'order_reference', v_rec.order_reference,
          'paymob_transaction_id', v_rec.paymob_transaction_id,
          'tournament_id', p_tournament_id,
          'tournament_name', v_t.name,
          'refund_amount', v_refund_amt,
          'principal_amount', v_rec.amount,
          'original_gross_amount', v_rec.gross_amount,
          'non_refundable_fee_amount', round(greatest(v_rec.gross_amount-v_refund_amt,0),2),
          'reason', coalesce(p_reason, 'إلغاء البطولة')
        ),
        'طلب استرداد رسوم بطولة 1v1 عبر باي موب لإلغاء الدورة بقرار الإدارة',
        v_now, v_now
      );
    END IF;

    INSERT INTO public.notifications (
      user_id, title, body, type, created_at
    ) VALUES (
      v_rec.user_id,
      'إلغاء البطولة وطلب استرداد الرسوم 💳',
      'تم إلغاء ' || coalesce(v_t.name, 'بطولة 1v1') || ' لظروف تنظيمية، وتم رفع طلب استرداد رسمي لمبلغ (' || v_refund_amt || ' ج.م) عبر باي موب لإعادتها إلى وسيلة الدفع الخاصة بك.',
      'tournament_refund',
      v_now
    );
  END LOOP;

  UPDATE public.vsp_1v1_tournaments
  SET status = 'cancelled',
      prize_pool = 0,
      updated_at = v_now
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم إلغاء البطولة ومعالجة طلبات استرداد الرسوم بنجاح',
    'refunded_count', v_count
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_1v1_tournament_with_refund_requests(uuid,text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.cancel_1v1_tournament_with_refund_requests(uuid,text) TO authenticated,service_role;

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

REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(p_booking_id uuid, p_reason text DEFAULT 'إلغاء حجز من المستخدم'::text, p_user_id uuid DEFAULT NULL::uuid)
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
                            ELSE CASE
                              WHEN lower(coalesce(payment_method, '')) = 'cash' THEN 'cancelled'
                              ELSE payment_status
                            END
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
                        ELSE 'cancelled'
                      END,
    'booking_id',     p_booking_id,
    'transaction_id', v_tx_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid,text,uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric DEFAULT NULL::numeric, p_collected_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_cash_amount numeric; v_actual_deposit numeric; v_total_price numeric; v_remaining numeric; v_target_status text; v_now timestamptz:=timezone('utc',now());
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;
 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','super_admin','cofounder')
  THEN RETURN jsonb_build_object('success',false,'message','غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.'); END IF;
 END IF;
 IF v_booking.status='cancelled' THEN RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي' USING ERRCODE='P0003',DETAIL='BOOKING_CANCELLED'; END IF;
 IF coalesce(v_booking.payment_method,'')<>'cash' THEN RETURN jsonb_build_object('success',false,'message','لا يمكن تأكيد حجز غير نقدي كتحصيل كاش.'); END IF;
 IF v_booking.is_paid IS TRUE AND v_booking.payment_status='paid' THEN
  RETURN jsonb_build_object('success',true,'message','الحجز مؤكد ومسدد بالفعل مسبقاً.','already_confirmed',true,'booking_id',p_booking_id,'amount',0,'commission',0,'total_price',v_booking.total_price,'payment_method',v_booking.payment_method);
 END IF;
 v_total_price:=coalesce(v_booking.total_price,0);
 IF v_total_price<=0 THEN RETURN jsonb_build_object('success',false,'message','قيمة الحجز غير صالحة.'); END IF;
 IF p_total_price IS NOT NULL AND abs(p_total_price-v_total_price)>0.01 THEN RETURN jsonb_build_object('success',false,'message','قيمة الحجز المرسلة لا تطابق القيمة المسجلة.','expected_total_price',v_total_price); END IF;
 v_actual_deposit:=greatest(coalesce(v_booking.deposit_paid,0),0);
 v_remaining:=greatest(round(v_total_price-v_actual_deposit,2),0);
 IF v_remaining<=0 THEN
  UPDATE public.bookings SET is_paid=true,payment_status='paid',status=case when v_now>=end_time then 'completed' else status end,updated_at=v_now WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'amount',0,'deposit_paid',v_actual_deposit,'total_price',v_total_price,'commission',0,'status',case when v_now>=v_booking.end_time then 'completed' else v_booking.status end,'payment_status','paid','already_confirmed',true);
 END IF;
 IF p_collected_amount IS NULL THEN v_cash_amount:=v_remaining; ELSE v_cash_amount:=round(p_collected_amount,2); END IF;
 IF v_cash_amount<=0 OR v_cash_amount>v_remaining THEN RETURN jsonb_build_object('success',false,'message','مبلغ التحصيل النقدي يجب أن يساوي المبلغ المتبقي ولا يتجاوزه.','remaining_amount',v_remaining); END IF;
 IF abs(v_cash_amount-v_remaining)>0.01 THEN RETURN jsonb_build_object('success',false,'message','تأكيد التحصيل لا يتم إلا للمبلغ النقدي المتبقي بالكامل.','remaining_amount',v_remaining); END IF;
 v_target_status:=case when v_now>=v_booking.end_time then 'completed' else 'confirmed' end;
 UPDATE public.bookings SET is_paid=true,payment_status='paid',status=v_target_status,deposit_paid=v_total_price,vsp_commission=0,updated_at=v_now WHERE id=p_booking_id;
 INSERT INTO public.transactions(user_id,booking_id,amount,type,status,payment_method,description,created_at,updated_at)
 VALUES(v_booking.owner_id,p_booking_id,v_cash_amount,'cash_settlement','completed','cash','تحصيل كاش مؤكد بالملعب لحجز #'||substring(p_booking_id::text,1,8),v_now,v_now)
 ON CONFLICT (booking_id) WHERE type='cash_settlement' AND status='completed' DO UPDATE SET amount=EXCLUDED.amount,updated_at=v_now;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'amount',v_cash_amount,'deposit_paid',v_total_price,'total_price',v_total_price,'commission',0,'status',v_target_status,'payment_status','paid');
END;$function$;

REVOKE ALL ON FUNCTION public.confirm_cash_booking_atomic(uuid,uuid,numeric,numeric) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid,uuid,numeric,numeric) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.create_booking_atomic(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text DEFAULT ''::text, p_stadium_image_url text DEFAULT ''::text, p_is_private boolean DEFAULT true, p_rent_ball boolean DEFAULT false, p_needs_deposit boolean DEFAULT false, p_deposit_amount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_payment_status text DEFAULT 'pending'::text, p_player_team_id text DEFAULT NULL::text, p_player_team_name text DEFAULT NULL::text, p_opponent_team_id text DEFAULT NULL::text, p_opponent_team_name text DEFAULT NULL::text, p_platform_fee numeric DEFAULT 0, p_idempotency_key text DEFAULT NULL::text, p_initial_players integer DEFAULT 1, p_total_capacity integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium record;
  v_caller uuid := auth.uid();
  v_caller_role text;
  v_duration_hours numeric;
  v_calculated_price numeric;
  v_hourly_rate numeric;
  v_ball_price numeric := 0;
  v_final_total_price numeric;
  v_final_needs_deposit boolean;
  v_final_deposit_amount numeric;
  v_final_deposit_paid numeric := 0;
  v_final_status text;
  v_final_is_paid boolean;
  v_locked_until timestamptz;
  v_active_cash_count int := 0;
  v_conflict_count int := 0;
  v_user_blocked boolean;
  v_no_show_count int;
  v_new_booking_id uuid;
  v_existing_id uuid;
  v_existing_status text;
  v_now timestamptz := timezone('utc', now());
  v_initial_players int;
  v_capacity int;
  v_raw_type text;
  v_normalized_type text;
BEGIN
  v_raw_type := lower(trim(coalesce(p_booking_type,'')));
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
    IF v_caller::text<>p_user_id
       AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin')
       AND current_user NOT IN ('postgres','service_role') THEN
      RETURN jsonb_build_object('success',false,'message','غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
    END IF;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id,status INTO v_existing_id,v_existing_status
    FROM public.bookings
    WHERE idempotency_key=p_idempotency_key AND status<>'cancelled'
    LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success',true,'booking_id',v_existing_id,'status',v_existing_status,'idempotent',true);
    END IF;
  END IF;

  v_duration_hours:=extract(epoch from(p_end_time-p_start_time))/3600.0;
  IF v_duration_hours<=0 THEN
    RETURN jsonb_build_object('success',false,'message','وقت بداية ونهاية الحجز غير صالح.');
  END IF;

  IF v_duration_hours<((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id=1)/60.0)
     OR v_duration_hours>(SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id=1) THEN
    RETURN jsonb_build_object('success',false,'message','مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id,0));

  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text=p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الملعب المطلوب غير موجود.'); END IF;
  IF v_stadium.is_deleted_by_owner THEN RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب محذوف.'); END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;


  IF NOT public.vsp_validate_stadium_booking_window(
    v_stadium.opening_time,
    v_stadium.closing_time,
    v_stadium.break_start_time,
    v_stadium.break_end_time,
    v_stadium.is_split_shift,
    v_stadium.maintenance_until,
    p_start_time,
    p_end_time
  ) THEN
    RETURN jsonb_build_object(
      'success',false,
      'code','OUTSIDE_OPERATING_HOURS',
      'message','موعد الحجز خارج ساعات تشغيل الملعب أو يتعارض مع فترة التوقف أو الصيانة.'
    );
  END IF;



  SELECT is_blocked,coalesce(no_show_count,0)
  INTO v_user_blocked,v_no_show_count
  FROM public.users WHERE id::text=p_user_id;

  IF coalesce(v_user_blocked,false) THEN
    RETURN jsonb_build_object('success',false,'message','حسابك مقيد حالياً.');
  END IF;

  IF lower(coalesce(p_payment_method,''))='cash'
     AND v_no_show_count>=(SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id=1) THEN
    RETURN jsonb_build_object('success',false,'message','حسابك مقيد عن الحجز النقدي.');
  END IF;

  SELECT COUNT(*) INTO v_active_cash_count
  FROM public.bookings
  WHERE (user_id::text=p_user_id OR created_by_user_id::text=p_user_id)
    AND lower(coalesce(payment_method,''))='cash'
    AND status IN('pending','confirmed')
    AND coalesce(is_paid,false)=false
    AND end_time>v_now;

  IF lower(coalesce(p_payment_method,''))='cash' AND v_active_cash_count>0 THEN
    RETURN jsonb_build_object(
      'success',false,'code','ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online',true,
      'message','لديك حجز نقدي غير مسدد قائم بالفعل. يرجى سداده أولاً أو الدفع إلكترونياً.'
    );
  END IF;

  v_final_needs_deposit:=coalesce(v_stadium.needs_deposit,false);
  v_final_deposit_amount:=case when v_final_needs_deposit then coalesce(v_stadium.deposit_amount,0) else 0 end;

  -- A stadium that requires an upfront deposit must never allow a cash booking.
  -- The deposit is an online prepayment requirement; the server is authoritative.
  IF lower(coalesce(p_payment_method,''))='cash'
     AND v_final_needs_deposit
     AND v_final_deposit_amount > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ONLINE_DEPOSIT_REQUIRED',
      'requires_online_deposit', true,
      'deposit_amount', v_final_deposit_amount,
      'message', 'هذا الملعب يتطلب دفع العربون إلكترونياً لتأكيد الحجز.'
    );
  END IF;
  v_hourly_rate:=coalesce(v_stadium.price_per_hour,v_stadium.base_price,0);
  v_calculated_price:=round(v_hourly_rate*v_duration_hours,2);

  IF p_rent_ball THEN
    BEGIN
      v_ball_price:=coalesce((v_stadium.features->>'ballPrice')::numeric,0);
    EXCEPTION WHEN OTHERS THEN
      v_ball_price:=0;
    END;
    v_calculated_price:=v_calculated_price+v_ball_price;
  END IF;

  IF v_calculated_price<=0 THEN
    RETURN jsonb_build_object('success',false,'message','تسعيرة الملعب غير صحيحة.');
  END IF;

  v_final_total_price:=v_calculated_price;

  IF lower(coalesce(p_payment_method,'')) IN ('paymob','card','wallet','online') THEN
    v_final_status:='pending';
    v_final_is_paid:=false;
    v_locked_until:=v_now+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval;
  ELSE
    v_final_status:='confirmed';
    v_final_is_paid:=false;
    v_locked_until:=NULL;
  END IF;

  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text=p_stadium_id AND status<>'cancelled'
    AND NOT(status='pending' AND coalesce(locked_until,created_at+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval)<v_now)
    AND p_start_time<end_time AND p_end_time>start_time;

  IF v_conflict_count>0 THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، هذا الموعد محجوز أو قيد الدفع من لاعب آخر حالياً.');
  END IF;

  IF v_normalized_type='open_join' THEN
    v_initial_players:=coalesce(p_initial_players,1);

    IF v_initial_players<1 THEN
      RETURN jsonb_build_object('success',false,'code','INVALID_INITIAL_PLAYERS','message','عدد اللاعبين المبدئي يجب أن يكون 1 على الأقل.');
    END IF;

    v_capacity:=v_stadium.total_field_capacity;

    IF v_capacity IS NULL OR v_capacity<1 THEN
      RETURN jsonb_build_object('success',false,'code','STADIUM_CAPACITY_NOT_CONFIGURED','message','هذا الملعب لا تتوفر له سعة محددة. لا يمكن إنشاء الحجز التجميعي حتى يقوم المالك بتحديد السعة.');
    END IF;

    IF v_initial_players>v_capacity THEN
      RETURN jsonb_build_object('success',false,'code','INITIAL_PLAYERS_EXCEED_CAPACITY','message','عدد اللاعبين المبدئي ('||v_initial_players||') لا يمكن أن يتجاوز سعة الملعب ('||v_capacity||').');
    END IF;
  ELSE
    v_initial_players:=1;
    v_capacity:=NULL;
  END IF;

  INSERT INTO public.bookings(
    stadium_id,user_id,created_by_user_id,owner_id,
    start_time,end_time,booking_type,total_price,vsp_commission,gateway_fee,platform_fee,
    stadium_name,stadium_image_url,is_private,rent_ball,
    needs_deposit,deposit_amount,deposit_paid,
    payment_method,payment_status,status,is_paid,
    player_team_id,player_team_name,opponent_team_id,opponent_team_name,challenge_status,
    joined_user_ids,current_players,initial_players_count,manual_player_count,total_field_capacity,
    locked_until,idempotency_key,created_at,updated_at
  ) VALUES(
    p_stadium_id::uuid,p_user_id::uuid,p_user_id::uuid,v_stadium.owner_id,
    p_start_time,p_end_time,v_normalized_type,
    v_final_total_price,0,0,0,
    v_stadium.name,v_stadium.image_url,
    case when v_normalized_type='open_join' then true else p_is_private end,
    p_rent_ball,
    v_final_needs_deposit,v_final_deposit_amount,v_final_deposit_paid,
    lower(coalesce(p_payment_method,'cash')),'pending',v_final_status,v_final_is_paid,
    case when p_player_team_id~'^[0-9a-fA-F-]{36}$' then p_player_team_id::uuid else null end,
    p_player_team_name,
    case when p_opponent_team_id~'^[0-9a-fA-F-]{36}$' then p_opponent_team_id::uuid else null end,
    p_opponent_team_name,
    null,
    ARRAY[p_user_id::uuid],
    v_initial_players,
    v_initial_players,
    case when v_normalized_type='open_join' then greatest(v_initial_players-1,0) else 0 end,
    v_capacity,
    v_locked_until,p_idempotency_key,v_now,v_now
  )
  RETURNING id INTO v_new_booking_id;

  RETURN jsonb_build_object(
    'success',true,
    'booking_id',v_new_booking_id,
    'status',v_final_status,
    'total_price',v_final_total_price,
    'needs_deposit',v_final_needs_deposit,
    'deposit_amount',v_final_deposit_amount,
    'initial_players',v_initial_players,
    'manual_player_count',case when v_normalized_type='open_join' then greatest(v_initial_players-1,0) else 0 end,
    'total_capacity',v_capacity,
    'requires_full_online',(v_active_cash_count>0 AND lower(coalesce(p_payment_method,'')) IN ('paymob','card','wallet','online')),
    'locked_until',v_locked_until
  );
EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$;

REVOKE ALL ON FUNCTION public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.create_booking_atomic(text,text,text,timestamp with time zone,timestamp with time zone,text,numeric,text,text,boolean,boolean,boolean,numeric,text,text,text,text,text,text,numeric,text,integer,integer) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.mark_1v1_prize_delivered_atomic(p_tournament_id uuid, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_champ RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 🔒 Authorization: Only admin or co_founder
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط الأدمن يمكنه توثيق تسليم الجوائز.');
        END IF;
    END IF;

    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تسليم الجائزة قبل انتهاء البطولة وتتويج البطل رسمياً.');
    END IF;

    IF v_champ.prize_delivered = true THEN
        RETURN jsonb_build_object(
            'success', false, 
            'already_delivered', true, 
            'error', 'تم توثيق تسليم الجائزة بالفعل مسبقاً في: ' || v_champ.prize_delivered_at::text
        );
    END IF;

    -- Update tournament with delivery metadata (Pure audit log, no wallet movements)
    UPDATE public.vsp_1v1_tournaments
    SET 
        prize_delivered = true,
        prize_delivered_at = v_now,
        prize_delivered_by = v_caller_id,
        prize_delivery_notes = p_notes,
        updated_at = v_now
    WHERE id = p_tournament_id;

    -- Notify champion
    IF v_champ.champion_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_champ.champion_user_id,
            'توثيق استلام الجائزة المالية 🏆',
            'تهانينا! تم توثيق استلامك لجائزة بطولة ' || COALESCE(v_champ.name, '1v1') || ' وقدرها ' || COALESCE(v_champ.prize_pool, 0) || ' ج.م بنجاح.',
            'tournament_update',
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'prize_delivered', true,
        'prize_pool', v_champ.prize_pool,
        'champion_user_id', v_champ.champion_user_id,
        'delivered_at', v_now
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.mark_1v1_prize_delivered_atomic(uuid,text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic(uuid,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.owner_cancel_manual_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_refund_deposit boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_now timestamptz:=timezone('utc',now()); v_deposit numeric;
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;
 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); END IF;
 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','super_admin','cofounder')
  THEN RETURN jsonb_build_object('success',false,'message','غير مصرح.'); END IF;
 END IF;
 IF v_booking.status='cancelled' THEN RETURN jsonb_build_object('success',true,'message','الحجز ملغي بالفعل مسبقاً.'); END IF;
 IF v_booking.start_time<=v_now THEN RETURN jsonb_build_object('success',false,'message','لا يمكن إلغاء الحجز اليدوي بعد بدء موعده.'); END IF;
 v_deposit:=coalesce(v_booking.deposit_paid,0);
 IF p_refund_deposit IS TRUE AND v_deposit>0 THEN
  INSERT INTO public.transactions(user_id,booking_id,amount,type,status,payment_method,description,created_at,updated_at)
  VALUES(v_booking.owner_id,p_booking_id,v_deposit,'cash_refund','completed','cash','استرداد عربون حجز يدوي ملغي: '||coalesce(v_booking.stadium_name,'الملعب'),v_now,v_now);
  UPDATE public.bookings SET status='cancelled',deposit_paid=0,is_deposit_paid=false,is_paid=false,cancellation_reason='تم إلغاء الحجز اليدوي ورد العربون للعميل',cancelled_at=v_now,updated_at=v_now WHERE id=p_booking_id;
 ELSE
  UPDATE public.bookings SET status='cancelled',cancellation_reason=CASE WHEN v_deposit>0 THEN 'تم إلغاء الحجز اليدوي مع الاحتفاظ بالعربون كشرط جزائي' ELSE 'تم إلغاء الحجز اليدوي' END,cancelled_at=v_now,updated_at=v_now WHERE id=p_booking_id;
 END IF;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'deposit_refunded',p_refund_deposit AND v_deposit>0,'refunded_amount',CASE WHEN p_refund_deposit AND v_deposit>0 THEN v_deposit ELSE 0 END);
END;$function$;

REVOKE ALL ON FUNCTION public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.owner_cancel_manual_booking_atomic(uuid,uuid,boolean) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_total_price numeric DEFAULT 0, p_collected_amount numeric DEFAULT 0, p_current_players integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_stadium record; v_role text; v_actual_owner_id uuid; v_authorized boolean:=false;
v_duration numeric; v_server_total numeric; v_collected numeric; v_booking_id uuid; v_tx_id uuid; v_ref text; v_now timestamptz:=now();
begin
select * into v_stadium from public.stadiums where id=p_stadium_id for update;
if not found then return jsonb_build_object('success',false,'error','STADIUM_NOT_FOUND'); end if;
v_actual_owner_id:=v_stadium.owner_id;
if v_stadium.is_deleted_by_owner is true or coalesce(v_stadium.is_blocked,false) or coalesce(v_stadium.is_verified,false) is false then return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE'); end if;
select role into v_role from public.users where id=auth.uid();
if auth.role()='service_role' or current_user in ('postgres','service_role') or v_actual_owner_id=auth.uid() or coalesce(v_role,'') in ('admin','co_founder','cofounder','super_admin') then v_authorized:=true; end if;
if not v_authorized then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
if p_end_time<=p_start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
v_duration:=extract(epoch from(p_end_time-p_start_time))/3600;
if v_duration<=0 or v_duration>(select manual_booking_max_duration_hours from public.platform_business_rules where id=1) then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
v_server_total:=round(coalesce(v_stadium.price_per_hour,v_stadium.base_price,0)*v_duration,2);
if v_server_total<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
if abs(coalesce(p_total_price,0)-v_server_total)>0.01 then return jsonb_build_object('success',false,'error','PRICE_MISMATCH','expected_total_price',v_server_total); end if;
v_collected:=round(coalesce(p_collected_amount,0),2);
if v_collected < 0 or v_collected > v_server_total then
  return jsonb_build_object('success',false,'error','INVALID_COLLECTED_AMOUNT');
end if;
if p_start_time<v_now-(select booking_past_grace_minutes from public.platform_business_rules where id=1)*interval '1 minute' then return jsonb_build_object('success',false,'error','START_TIME_IN_PAST'); end if;
perform pg_advisory_xact_lock(hashtextextended(p_stadium_id::text,0));
if exists(select 1 from public.bookings b where b.stadium_id=p_stadium_id and b.status<>'cancelled' and p_start_time<b.end_time and p_end_time>b.start_time) then return jsonb_build_object('success',false,'error','conflict','code','SLOT_LOCKED_OR_TAKEN'); end if;
v_ref:='MANUAL_'||replace(gen_random_uuid()::text,'-','');
perform set_config('vsp.manual_booking_workflow','true',true);
insert into public.bookings(stadium_id,stadium_name,owner_id,user_id,created_by_user_id,start_time,end_time,booking_type,player_team_name,host_name,player_phone,notes,total_price,vsp_commission,gateway_fee,platform_fee,deposit_paid,is_deposit_paid,is_paid,payment_status,payment_method,payment_transaction_id,status,current_players,is_private,rent_ball,created_at,updated_at)
values(
  p_stadium_id,v_stadium.name,v_actual_owner_id,v_actual_owner_id,coalesce(auth.uid(),v_actual_owner_id),
  p_start_time,p_end_time,'personal',nullif(trim(p_customer_name),''),nullif(trim(p_customer_name),''),
  nullif(trim(p_customer_phone),''),nullif(trim(p_notes),''),v_server_total,0,0,0,
  v_collected,v_collected>0,v_collected>=v_server_total,
  case when v_collected>=v_server_total then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end,
  'cash',v_ref,'confirmed',null,true,false,v_now,v_now
)
returning id into v_booking_id;
insert into public.transactions(user_id,booking_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
values(v_actual_owner_id,v_booking_id,v_collected,'cash_settlement','completed','cash',v_ref,'تحصيل نقدي لحجز يدوي',jsonb_build_object('principal_amount',v_collected,'gross_amount',v_collected,'vsp_fee',0,'gateway_fee',0,'total_payment_fees',0,'server_recorded_at',v_now),v_now,v_now)
returning id into v_tx_id;
perform set_config('vsp.manual_booking_workflow','',true);
return jsonb_build_object(
  'success',true,
  'booking_id',v_booking_id,
  'total_price',v_server_total,
  'collected_amount',v_collected,
  'remaining_amount',greatest(v_server_total-v_collected,0),
  'payment_status',case when v_collected>=v_server_total then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end,
  'transaction_id',v_tx_id
);
exception when others then perform set_config('vsp.manual_booking_workflow','',true); return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end; $function$;

REVOKE ALL ON FUNCTION public.owner_create_manual_booking_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text,text,text,numeric,numeric,integer) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(uuid,uuid,timestamp with time zone,timestamp with time zone,text,text,text,numeric,numeric,integer) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.owner_record_no_show_atomic(p_booking_id uuid, p_owner_id uuid, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_booking record; v_caller_role text; v_now timestamptz:=timezone('utc',now()); v_player_id uuid;
BEGIN
 SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.'); END IF;

 IF p_owner_id IS DISTINCT FROM v_booking.owner_id THEN
  RETURN jsonb_build_object('success',false,'message','بيانات مالك الملعب غير متطابقة.'); 
 END IF;

 IF coalesce(auth.role(),'')<>'service_role' AND current_user NOT IN ('postgres','service_role') THEN
  SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
  IF auth.uid() IS DISTINCT FROM v_booking.owner_id
     AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
   RETURN jsonb_build_object('success',false,'message','غير مصرح: تسجيل عدم الحضور متاح فقط لمالك الملعب أو الإدارة.');
  END IF;
 END IF;

 IF v_booking.status='no_show' THEN RETURN jsonb_build_object('success',true,'message','تم تسجيل عدم الحضور مسبقاً.'); END IF;
 IF v_booking.status='cancelled' THEN RETURN jsonb_build_object('success',false,'message','لا يمكن تسجيل عدم الحضور لحجز ملغى.'); END IF;
 IF v_booking.end_time IS NULL OR v_booking.end_time>v_now THEN
  RETURN jsonb_build_object('success',false,'message','لا يمكن تسجيل عدم الحضور قبل انتهاء موعد الحجز.'); 
 END IF;

 v_player_id:=coalesce(v_booking.user_id,v_booking.created_by_user_id);

 UPDATE public.bookings
 SET status='no_show',
     is_paid=(coalesce(deposit_paid,0)>0),
     payment_status=CASE WHEN coalesce(deposit_paid,0)>0 THEN 'paid' ELSE payment_status END,
     cancellation_reason='غياب اللاعب وعدم الحضور بالموعد المحدد (العربون تعويض للملعب)',
     notes=CASE WHEN length(trim(coalesce(p_notes,'')))>0 THEN coalesce(notes,'')||' | '||trim(p_notes) ELSE notes END,
     updated_at=v_now
 WHERE id=p_booking_id;

 IF v_player_id IS NOT NULL THEN
  UPDATE public.users SET fair_play_score=greatest(0,coalesce(fair_play_score,100)-10),updated_at=v_now WHERE id=v_player_id;
  INSERT INTO public.notifications(user_id,title,body,type,created_at)
  VALUES(v_player_id,'تسجيل عدم حضور (No-Show)',
   'تم تسجيل عدم حضورك للمباراة المقررة في '||coalesce(v_booking.stadium_name,'الملعب')||'. تم احتساب العربون تعويضاً للملعب وفق شروط الحجز.',
   'booking_no_show',v_now);
 END IF;

 RETURN jsonb_build_object('success',true,'message','تم تسجيل عدم حضور اللاعب واعتماد العربون كتعويض للملعب بنجاح.');
END;$function$;

REVOKE ALL ON FUNCTION public.owner_record_no_show_atomic(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.owner_record_no_show_atomic(uuid,uuid,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.publish_1v1_final_standings_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caller_role text; v_champ record; v_champion_user_id uuid; v_champion_name text; v_champion_team_id uuid; v_prize numeric;
BEGIN
IF coalesce(auth.role(),'') <> 'service_role' AND current_user <> 'postgres' THEN SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid(); IF coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','غير مصرح: فقط الأدمن يمكنه اعتماد ونشر النتائج.'); END IF; END IF;
SELECT * INTO v_champ FROM public.vsp_1v1_tournaments WHERE id=p_tournament_id FOR UPDATE;
IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','البطولة غير موجودة.'); END IF;
v_champion_user_id:=v_champ.champion_user_id;
IF v_champion_user_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','يجب اعتماد بطل البطولة أولاً. الترتيب بالنقاط لا يحدد البطل تلقائياً.'); END IF;
SELECT user_id,player_name INTO v_champion_user_id,v_champion_name FROM public.vsp_1v1_tournament_players WHERE tournament_id=p_tournament_id AND user_id=v_champion_user_id AND payment_status='paid' LIMIT 1;
IF v_champion_user_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','البطل المختار يجب أن يكون لاعباً مسدداً ومسجلاً في البطولة.'); END IF;
UPDATE public.vsp_1v1_tournaments SET status='archived' WHERE governorate=v_champ.governorate AND status IN ('completed','published') AND id<>p_tournament_id;
UPDATE public.vsp_1v1_tournaments SET status='completed',published_at=coalesce(published_at,timezone('utc',now())),champion_user_id=v_champion_user_id,updated_at=timezone('utc',now()) WHERE id=p_tournament_id;
v_prize:=coalesce(v_champ.prize_amount,v_champ.prize_pool,0);
IF NOT EXISTS (SELECT 1 FROM public.player_trophies WHERE user_id=v_champion_user_id AND tournament_1v1_id=p_tournament_id) THEN
 INSERT INTO public.player_trophies(id,user_id,tournament_1v1_id,title,prize_won,created_at) VALUES(gen_random_uuid(),v_champion_user_id,p_tournament_id,'بطل تحدي 1v1 - '||coalesce(v_champ.name,'VSP 1v1')||' ('||coalesce(v_champ.governorate,'')||')',v_prize,timezone('utc',now()));
END IF;
SELECT team_id INTO v_champion_team_id FROM public.team_members WHERE user_id=v_champion_user_id LIMIT 1;
IF v_champion_team_id IS NOT NULL THEN UPDATE public.teams SET has_1v1_champion=true WHERE id=v_champion_team_id; END IF;
RETURN jsonb_build_object('success',true,'tournament_id',p_tournament_id,'governorate',v_champ.governorate,'champion_user_id',v_champion_user_id,'champion_name',v_champion_name,'champion_team_id',v_champion_team_id,'status','completed');
END;$function$;

REVOKE ALL ON FUNCTION public.publish_1v1_final_standings_atomic(uuid) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.publish_1v1_final_standings_atomic(uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(p_owner_id uuid, p_amount numeric, p_method text DEFAULT 'instapay'::text, p_destination text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_pending_count integer; v_settlement_id uuid; v_owner record; v_caller_role text;
 v_now timestamptz:=timezone('utc',now()); v_online_earned numeric:=0;
 v_total_withdrawn numeric:=0; v_pending_payouts numeric:=0; v_available_balance numeric:=0;
 v_method text; v_destination text;
begin
 if auth.uid() is null and current_user not in ('postgres','service_role') then return jsonb_build_object('success',false,'error','Authentication required'); end if;
 if auth.uid() is not null and auth.uid()<>p_owner_id and current_user not in ('postgres','service_role') then
  select role into v_caller_role from public.users where id=auth.uid();
  if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then return jsonb_build_object('success',false,'error','Unauthorized payout request'); end if;
 end if;
 if p_amount is null or p_amount<=0 then return jsonb_build_object('success',false,'error','يجب أن يكون مبلغ السحب أكبر من الصفر.'); end if;
 select * into v_owner from public.users where id=p_owner_id for update;
 if not found then return jsonb_build_object('success',false,'error','حساب المالك غير موجود.'); end if;

 v_method:=lower(trim(coalesce(p_method,'')));
 v_method:=case v_method when 'wallet' then 'vodafone_cash' when 'vodafone' then 'vodafone_cash' when 'bank' then 'bank_transfer' else v_method end;
 if v_method not in ('instapay','vodafone_cash','bank_transfer') then return jsonb_build_object('success',false,'error','وسيلة السحب غير مدعومة.'); end if;

 v_destination:=case v_method
  when 'instapay' then trim(coalesce(v_owner.p2p_instapay,''))
  when 'vodafone_cash' then trim(coalesce(v_owner.p2p_vodafone,''))
  when 'bank_transfer' then trim(coalesce(v_owner.p2p_bank,''))
 end;
 if v_destination='' then return jsonb_build_object('success',false,'error','بيانات جهة التحويل لهذه الوسيلة غير مسجلة في حسابك.'); end if;
 if p_destination is not null and trim(p_destination)<>'' and trim(p_destination)<>v_destination then
  return jsonb_build_object('success',false,'error','بيانات جهة التحويل تغيرت عن البيانات المسجلة. حدّث إعدادات الحساب ثم أعد المحاولة.'); end if;

 select count(*) into v_pending_count from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');
 if v_pending_count>0 then return jsonb_build_object('success',false,'error','لديك طلب سحب قيد المراجعة بالفعل.'); end if;

 select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0)
 into v_online_earned
 from public.bookings b
 where b.owner_id=p_owner_id
   and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
   and (b.payment_status='paid' or b.is_paid=true)
   and b.status in ('completed','no_show');

 select coalesce(sum(amount),0) into v_total_withdrawn from public.payout_settlements where owner_id=p_owner_id and status='completed';
 select coalesce(sum(amount),0) into v_pending_payouts from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');
 v_available_balance:=greatest(0,v_online_earned-v_total_withdrawn-v_pending_payouts);

 if round(p_amount,2)>round(v_available_balance,2)+0.01 then
  return jsonb_build_object('success',false,'error','المبلغ المطلوب ('||round(p_amount,2)||' ج.م) يتجاوز رصيدك المتاح للسحب ('||round(v_available_balance,2)||' ج.م).','available_balance',round(v_available_balance,2));
 end if;

 insert into public.payout_settlements(owner_id,amount,method,destination,status,created_at,updated_at)
 values(p_owner_id,round(p_amount,2),v_method,v_destination,'pending',v_now,v_now) returning id into v_settlement_id;

 insert into public.transactions(user_id,amount,type,status,payment_method,metadata,created_at,updated_at)
 values(p_owner_id,round(p_amount,2),'payout_pending','pending',v_method,
 jsonb_build_object('settlement_id',v_settlement_id,'destination',v_destination,'owner_name',coalesce(v_owner.name,'Unknown Owner'),
 'owner_phone',coalesce(v_owner.phone,''),'remaining_balance_after',round(v_available_balance-p_amount,2)),v_now,v_now);

 insert into public.notifications(user_id,title,body,type,is_read,created_at)
 select id,'طلب سحب أرباح جديد','طلب المالك '||coalesce(v_owner.name,'مالك')||' سحب '||round(p_amount,2)||' ج.م عبر '||v_method,'payout',false,v_now
 from public.users where role in ('admin','co_founder','cofounder','super_admin');

 return jsonb_build_object('success',true,'settlement_id',v_settlement_id,'available_balance',round(v_available_balance-p_amount,2),
 'method',v_method,'destination',v_destination,'message','تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.');
end;
$function$;

REVOKE ALL ON FUNCTION public.request_owner_payout_settlement_atomic(uuid,numeric,text,text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid,numeric,text,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic_impl(p_booking_id uuid, p_reason text DEFAULT 'cancelled_by_user'::text)
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

  IF coalesce(auth.role(), '') <> 'service_role' THEN
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

REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic_impl(uuid,text) FROM PUBLIC,anon,authenticated,service_role;

GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic_impl(uuid,text) TO service_role;

CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN public.confirm_cash_booking_atomic(p_booking_id,p_owner_id,p_total_price,NULL);
END;
$function$;

REVOKE ALL ON FUNCTION public.confirm_cash_booking_atomic(uuid,uuid,numeric) FROM PUBLIC,anon,authenticated;
