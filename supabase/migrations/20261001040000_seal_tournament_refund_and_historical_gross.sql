-- Migration: 20261001040000_seal_tournament_refund_and_historical_gross.sql
-- Description: Unifies historical gross amount persistence for team leagues & 1v1 tournaments,
-- seals refund trigger to row-level (FOR EACH ROW) on team league refund queue,
-- aligns cancellation states to failed_manual_review when payment info is missing,
-- and eliminates production schema drift.

-- 1. Ensure 1v1 cancellation refund queue table exists with strict RLS
CREATE TABLE IF NOT EXISTS public.vsp_1v1_cancellation_refund_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.vsp_1v1_tournaments(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.vsp_1v1_tournament_orders(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  paymob_transaction_id TEXT,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed_manual_review')),
  failure_reason TEXT,
  locked_until TIMESTAMPTZ,
  processed_at TIMESTAMPTZ,
  retry_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_vsp_1v1_cancellation_refund_queue_status_locked 
ON public.vsp_1v1_cancellation_refund_queue (status, locked_until);

ALTER TABLE public.vsp_1v1_cancellation_refund_queue ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.vsp_1v1_cancellation_refund_queue FROM anon, authenticated;
GRANT ALL ON public.vsp_1v1_cancellation_refund_queue TO service_role, postgres;

-- 2. Ensure Team League cancellation refund queue table exists with strict RLS
CREATE TABLE IF NOT EXISTS public.team_league_cancellation_refund_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  championship_id UUID NOT NULL REFERENCES public.championships(id) ON DELETE CASCADE,
  payment_id UUID NOT NULL REFERENCES public.team_league_payments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  paymob_transaction_id TEXT,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed_manual_review')),
  failure_reason TEXT,
  locked_until TIMESTAMPTZ,
  processed_at TIMESTAMPTZ,
  retry_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_team_league_cancellation_refund_queue_status_locked 
ON public.team_league_cancellation_refund_queue (status, locked_until);

ALTER TABLE public.team_league_cancellation_refund_queue ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.team_league_cancellation_refund_queue FROM anon, authenticated;
GRANT ALL ON public.team_league_cancellation_refund_queue TO service_role, postgres;

-- 3. Add historical gross_amount column to team_league_payments
ALTER TABLE public.team_league_payments 
ADD COLUMN IF NOT EXISTS gross_amount NUMERIC;

-- 4. Recreate Team League trigger as FOR EACH ROW
DROP TRIGGER IF EXISTS trg_team_league_cancellation_refund_queue_worker ON public.team_league_cancellation_refund_queue;

CREATE TRIGGER trg_team_league_cancellation_refund_queue_worker
AFTER INSERT ON public.team_league_cancellation_refund_queue
FOR EACH ROW
EXECUTE FUNCTION public.trigger_cancellation_refund_worker();

-- 5. Atomic Claim RPC for Team League cancellation queue
CREATE OR REPLACE FUNCTION public.claim_next_team_league_cancellation_refund_atomic()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rec RECORD;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_lease_duration INTERVAL := INTERVAL '2 minutes';
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    RETURN jsonb_build_object('found', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_rec
  FROM public.team_league_cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < v_now)
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  UPDATE public.team_league_cancellation_refund_queue
  SET status = 'processing',
      locked_until = v_now + v_lease_duration,
      retry_count = retry_count + 1,
      updated_at = v_now
  WHERE id = v_rec.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_rec.id,
      'championship_id', v_rec.championship_id,
      'payment_id', v_rec.payment_id,
      'user_id', v_rec.user_id,
      'paymob_transaction_id', v_rec.paymob_transaction_id,
      'amount', v_rec.amount,
      'retry_count', v_rec.retry_count + 1
    )
  );
END;
$function$;

-- 6. Atomic Claim RPC for 1v1 cancellation queue
CREATE OR REPLACE FUNCTION public.claim_next_1v1_cancellation_refund_atomic()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rec RECORD;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_lease_duration INTERVAL := INTERVAL '2 minutes';
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    RETURN jsonb_build_object('found', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_rec
  FROM public.vsp_1v1_cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < v_now)
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  UPDATE public.vsp_1v1_cancellation_refund_queue
  SET status = 'processing',
      locked_until = v_now + v_lease_duration,
      retry_count = retry_count + 1,
      updated_at = v_now
  WHERE id = v_rec.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_rec.id,
      'tournament_id', v_rec.tournament_id,
      'order_id', v_rec.order_id,
      'user_id', v_rec.user_id,
      'paymob_transaction_id', v_rec.paymob_transaction_id,
      'amount', v_rec.amount,
      'retry_count', v_rec.retry_count + 1
    )
  );
END;
$function$;

-- 7. Update confirm_team_league_payment to persist gross_amount
CREATE OR REPLACE FUNCTION public.confirm_team_league_payment(
  p_order_reference text, 
  p_paymob_transaction_id text, 
  p_gross_amount_cents integer, 
  p_gateway_type text DEFAULT 'card'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_payment public.team_league_payments%ROWTYPE;
  v_fee RECORD;
  v_gateway_rate NUMERIC;
  v_expected INTEGER;
  v_champ RECORD;
  v_paid TEXT[];
  v_count INTEGER;
  v_gross NUMERIC;
BEGIN
  SELECT * INTO v_payment 
  FROM public.team_league_payments 
  WHERE order_reference = p_order_reference FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'دفع الدوري غير موجود'; END IF;
  IF v_payment.payment_status = 'paid' THEN 
    RETURN jsonb_build_object('success', true, 'already_paid', true); 
  END IF;
  IF v_payment.payment_status <> 'pending' THEN 
    RAISE EXCEPTION 'حالة دفع غير صالحة'; 
  END IF;
  IF p_paymob_transaction_id IS NULL OR TRIM(p_paymob_transaction_id) = '' THEN 
    RAISE EXCEPTION 'رقم عملية الدفع غير صالح'; 
  END IF;

  SELECT booking_vsp_rate, booking_paymob_rate, booking_paymob_local_rate, booking_paymob_wallet_rate, booking_paymob_fixed_fee 
  INTO v_fee 
  FROM public.platform_fee_config 
  WHERE id = 1;

  v_gateway_rate := CASE 
    WHEN lower(COALESCE(p_gateway_type, '')) LIKE '%wallet%' 
    THEN COALESCE(v_fee.booking_paymob_wallet_rate, v_fee.booking_paymob_rate) 
    ELSE COALESCE(v_fee.booking_paymob_local_rate, v_fee.booking_paymob_rate) 
  END;

  v_expected := round((v_payment.amount + v_payment.amount * COALESCE(v_fee.booking_vsp_rate, 0.02) + v_payment.amount * v_gateway_rate + COALESCE(v_fee.booking_paymob_fixed_fee, 3)) * 100);
  IF p_gross_amount_cents <> v_expected THEN 
    RAISE EXCEPTION 'مبلغ دفع الدوري غير مطابق'; 
  END IF;

  v_gross := round((p_gross_amount_cents::numeric / 100.0), 2);

  UPDATE public.team_league_payments 
  SET payment_status = 'paid',
      paymob_transaction_id = p_paymob_transaction_id,
      gross_amount = v_gross,
      paid_at = now(),
      updated_at = now() 
  WHERE id = v_payment.id;

  UPDATE public.championships 
  SET paid_teams = array_append(array_remove(COALESCE(paid_teams, '{}'::TEXT[]), v_payment.team_id::TEXT), v_payment.team_id::TEXT),
      updated_at = now() 
  WHERE id = v_payment.championship_id;

  SELECT * INTO v_champ FROM public.championships WHERE id = v_payment.championship_id FOR UPDATE;
  v_paid := COALESCE(v_champ.paid_teams, '{}'::TEXT[]);
  v_count := cardinality(v_paid);

  IF v_count >= v_champ.max_teams THEN
    PERFORM public.generate_team_league_fixtures(v_champ.id);
  END IF;

  RETURN jsonb_build_object('success', true, 'league_started', v_count >= v_champ.max_teams, 'gross_amount', v_gross);
END;
$function$;

-- 8. Update cancel_team_league to enforce historical gross & proper manual review states
CREATE OR REPLACE FUNCTION public.cancel_team_league(p_championship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE 
  v_uid UUID := auth.uid(); 
  v_owner UUID; 
  v_paid_count INT; 
  v_status TEXT;
  v_name TEXT;
  v_rec RECORD;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_queue_status TEXT;
  v_payment_status TEXT;
  v_tx_status TEXT;
  v_refund_amount NUMERIC;
  v_failure_reason TEXT;
  v_notif_body TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  
  SELECT owner_id, status, name, cardinality(coalesce(paid_teams, '{}'::text[]))
    INTO v_owner, v_status, v_name, v_paid_count
  FROM public.championships
  WHERE id = p_championship_id AND template_type = 'team_league'
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'الدوري غير موجود'; END IF;
  IF v_owner <> v_uid THEN RAISE EXCEPTION 'فقط منشئ الدوري يستطيع إلغاءه'; END IF;
  IF v_status <> 'open' THEN RAISE EXCEPTION 'لا يمكن إلغاء الدوري بعد بدء المنافسات'; END IF;

  FOR v_rec IN 
    SELECT * FROM public.team_league_payments 
    WHERE championship_id = p_championship_id AND payment_status = 'paid'
  LOOP
    IF v_rec.paymob_transaction_id IS NULL OR trim(v_rec.paymob_transaction_id) = '' THEN
      v_queue_status := 'failed_manual_review';
      v_payment_status := 'refund_failed_manual_review';
      v_tx_status := 'manual_review';
      v_failure_reason := 'Missing paymob_transaction_id; manual review required';
      v_refund_amount := COALESCE(v_rec.gross_amount, v_rec.amount);
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وجارٍ مراجعة طلب استرداد الرسوم يدوياً من قِبل إدارة التطبيق.';
    ELSIF v_rec.gross_amount IS NULL OR v_rec.gross_amount <= 0 THEN
      v_queue_status := 'failed_manual_review';
      v_payment_status := 'refund_failed_manual_review';
      v_tx_status := 'manual_review';
      v_failure_reason := 'Missing valid historical gross_amount; manual review required';
      v_refund_amount := v_rec.amount;
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وجارٍ مراجعة طلب استرداد الرسوم يدوياً من قِبل إدارة التطبيق.';
    ELSE
      v_queue_status := 'pending';
      v_payment_status := 'refund_requested';
      v_tx_status := 'pending';
      v_failure_reason := NULL;
      v_refund_amount := v_rec.gross_amount;
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وتم رفع طلب استرداد رسمي لمبلغ (' || v_refund_amount || ' ج.م) عبر باي موب لإعادتها إلى وسيلة الدفع الخاصة بك.';
    END IF;

    UPDATE public.team_league_payments
    SET payment_status = v_payment_status,
        updated_at = v_now
    WHERE id = v_rec.id;

    INSERT INTO public.team_league_cancellation_refund_queue (
      championship_id,
      payment_id,
      user_id,
      paymob_transaction_id,
      amount,
      status,
      failure_reason,
      created_at,
      updated_at
    ) VALUES (
      p_championship_id,
      v_rec.id,
      v_rec.user_id,
      v_rec.paymob_transaction_id,
      v_refund_amount,
      v_queue_status,
      v_failure_reason,
      v_now,
      v_now
    );

    INSERT INTO public.transactions(
      user_id, championship_id, amount, type, status, 
      payment_method, reference_number, paymob_transaction_id,
      metadata, description, created_at, updated_at
    ) VALUES (
      v_rec.user_id, p_championship_id, v_refund_amount, 'refund_request', v_tx_status,
      'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
      jsonb_build_object(
        'order_reference', v_rec.order_reference,
        'paymob_transaction_id', v_rec.paymob_transaction_id,
        'reason', 'league_cancelled_before_completion',
        'league_name', v_name,
        'gross_amount', v_refund_amount,
        'requires_manual_review', (v_queue_status = 'failed_manual_review')
      ),
      CASE 
        WHEN v_queue_status = 'failed_manual_review' THEN 'طلب استرداد رسوم دوري الفرق (يتطلب مراجعة يدوية)'
        ELSE 'طلب استرداد رسوم دوري الفرق عبر باي موب لإلغاء الدوري لعدم اكتمال الفرق'
      END,
      v_now, v_now
    );

    INSERT INTO public.notifications(
      user_id, title, body, type, created_at
    ) VALUES (
      v_rec.user_id,
      'إلغاء الدوري وطلب استرداد الرسوم 💳',
      v_notif_body,
      'tournament_refund',
      v_now
    );
  END LOOP;

  UPDATE public.championships
  SET status = 'cancelled',
      updated_at = v_now
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم إلغاء الدوري وتسجيل طلبات استرداد الرسوم بنجاح',
    'refund_requests_count', v_paid_count
  );
END;
$function$;

-- 9. Drop the old 2-argument overload of confirm_1v1_payment_atomic
DROP FUNCTION IF EXISTS public.confirm_1v1_payment_atomic(text, text);

-- 10. Update confirm_1v1_payment_atomic to strictly handle gross amount
CREATE OR REPLACE FUNCTION public.confirm_1v1_payment_atomic(
    p_order_reference text, 
    p_paymob_transaction_id text, 
    p_gross_amount numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_role TEXT;
    v_order RECORD;
    v_champ RECORD;
    v_current_count INT;
    v_user RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_gross NUMERIC;
    v_fee RECORD;
    v_calculated_gross NUMERIC;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: يتم تأكيد الطلبات عبر الـ Webhook فقط.');
        END IF;
    END IF;

    SELECT * INTO v_order 
    FROM public.vsp_1v1_tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'طلب الدفع غير موجود.');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'message', 'تم تأكيد الطلب مسبقاً.');
    END IF;

    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = v_order.tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة المرتبطة بالطلب غير موجودة.');
    END IF;

    IF p_gross_amount IS NOT NULL AND p_gross_amount > 0 THEN
        v_gross := round(p_gross_amount, 2);
    ELSE
        SELECT booking_vsp_rate, booking_paymob_local_rate, booking_paymob_rate, booking_paymob_fixed_fee
        INTO v_fee
        FROM public.platform_fee_config
        WHERE id = 1;
        
        v_calculated_gross := v_order.amount 
          + round(v_order.amount * COALESCE(v_fee.booking_vsp_rate, 0.02), 2)
          + round(v_order.amount * COALESCE(v_fee.booking_paymob_local_rate, v_fee.booking_paymob_rate, 0.0275), 2)
          + COALESCE(v_fee.booking_paymob_fixed_fee, 3);
        v_gross := round(v_calculated_gross, 2);
    END IF;

    SELECT COUNT(*) INTO v_current_count 
    FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = v_order.tournament_id AND payment_status = 'paid';

    IF v_champ.status != 'registration_open' OR v_current_count >= v_champ.target_player_count THEN
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'failed_over_capacity',
            paymob_transaction_id = p_paymob_transaction_id,
            gross_amount = v_gross,
            updated_at = v_now
        WHERE id = v_order.id;

        RETURN jsonb_build_object(
            'success', false,
            'capacity_exceeded', true,
            'needs_refund', true,
            'order_id', v_order.id,
            'order_reference', p_order_reference,
            'user_id', v_order.user_id,
            'tournament_id', v_order.tournament_id,
            'amount', v_order.amount,
            'gross_amount', v_gross,
            'paymob_transaction_id', p_paymob_transaction_id,
            'message', 'اكتملت مقاعد البطولة أثناء إتمام الدفع. تم إرسال أمر استرداد فوري لبوابة Paymob.'
        );
    END IF;

    UPDATE public.vsp_1v1_tournament_orders
    SET payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        gross_amount = v_gross,
        updated_at = v_now
    WHERE id = v_order.id;

    SELECT name, profile_image_url INTO v_user 
    FROM public.users 
    WHERE id = v_order.user_id;

    INSERT INTO public.vsp_1v1_tournament_players (
        tournament_id,
        user_id,
        player_name,
        avatar_url,
        tackles,
        goals,
        skills,
        payment_status,
        payment_order_id,
        paid_amount,
        registered_at
    ) VALUES (
        v_order.tournament_id,
        v_order.user_id,
        COALESCE(NULLIF(TRIM(v_user.name), ''), 'لاعب'),
        COALESCE(v_user.profile_image_url, ''),
        0,
        0,
        0,
        'paid',
        v_order.id,
        v_order.amount,
        v_now
    )
    ON CONFLICT (tournament_id, user_id) 
    DO UPDATE SET 
        payment_status = 'paid',
        payment_order_id = EXCLUDED.payment_order_id,
        paid_amount = EXCLUDED.paid_amount,
        registered_at = v_now;

    UPDATE public.vsp_1v1_tournaments
    SET prize_pool = COALESCE(prize_pool, 0) + v_order.amount,
        updated_at = v_now
    WHERE id = v_order.tournament_id;

    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        status,
        description,
        metadata,
        created_at
    ) VALUES (
        v_order.user_id,
        v_order.amount,
        'payment',
        'paymob',
        'completed',
        'رسوم اشتراك بطولة 1v1 - ' || COALESCE(v_champ.name, ''),
        jsonb_build_object(
            'tournament_id', v_order.tournament_id,
            'order_reference', p_order_reference,
            'paymob_transaction_id', p_paymob_transaction_id,
            'gross_amount', v_gross
        ),
        v_now
    );

    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    VALUES (
        v_order.user_id,
        'تأكيد التسجيل في بطولة 1v1 🎉',
        'تم تأكيد دفع رسوم الاشتراك (' || v_order.amount || ' ج.م) وتسجيلك رسمياً في ' || COALESCE(v_champ.name, 'البطولة') || '. حظاً موفقاً!',
        'tournament_update',
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', 'paid',
        'order_id', v_order.id,
        'tournament_id', v_order.tournament_id,
        'player_user_id', v_order.user_id,
        'amount', v_order.amount,
        'gross_amount', v_gross,
        'new_prize_pool', COALESCE(v_champ.prize_pool, 0) + v_order.amount
    );
END;
$function$;
