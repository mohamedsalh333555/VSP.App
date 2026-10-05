-- Migration: 20261005183000_owner_claim_and_security_definer_lockdown.sql
-- Description:
-- 1. Security Definer audit: revoke execute from public/anon/authenticated on internal helpers:
--    - vsp_chat_write_allowed
--    - vsp_user_is_booking_participant
--    - calculate_tournament_checkout_amount_atomic
-- 2. Harden check_owner_stadium_limit with authenticated caller ownership check
-- 3. Harden confirm_owner_subscription_payment and claim_paid_web_subscription_for_user:
--    - Protect admin/co_founder roles from being overwritten
--    - Prevent silent role conversion of existing players to owner from background web payment alone
--    - Enforce IDOR protection on claim_paid_web_subscription_for_user

-- 1. Internal helper lockdown
REVOKE EXECUTE ON FUNCTION public.vsp_chat_write_allowed(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.vsp_user_is_booking_participant(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.calculate_tournament_checkout_amount_atomic(UUID) FROM PUBLIC, anon, authenticated;

-- 2. check_owner_stadium_limit caller validation
CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_eval record;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_id AND NOT public.vsp_is_admin() THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(p_owner_id);
  RETURN jsonb_build_object(
    'allowed', v_eval.allowed,
    'current_count', v_eval.current_count,
    'max_allowed', v_eval.max_allowed,
    'is_trial', v_eval.is_trial,
    'is_sub_active', v_eval.is_sub_active,
    'plan_code', v_eval.plan_code,
    'message', v_eval.message
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.check_owner_stadium_limit(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_owner_stadium_limit(uuid) TO authenticated, service_role;

-- 3. Harden claim_paid_web_subscription_for_user
CREATE OR REPLACE FUNCTION public.claim_paid_web_subscription_for_user(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%rowtype;
  v_order public.owner_subscription_orders%rowtype;
  v_now timestamptz := now();
  v_expires timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_USER_ID');
  END IF;

  -- Caller ownership validation (prevents IDOR)
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id AND NOT public.vsp_is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  SELECT * INTO v_order
  FROM public.owner_subscription_orders
  WHERE status = 'paid'
    AND owner_id IS NULL
    AND lower(trim(checkout_email)) = lower(trim(v_user.email))
    AND nullif(trim(checkout_phone), '') IS NOT NULL
    AND nullif(trim(v_user.phone), '') IS NOT NULL
    AND regexp_replace(checkout_phone, '[^0-9+]', '', 'g') = regexp_replace(v_user.phone, '[^0-9+]', '', 'g')
    AND (claim_expires_at IS NULL OR claim_expires_at > v_now)
  ORDER BY paid_at DESC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_MATCHING_PAID_WEB_SUBSCRIPTION');
  END IF;

  v_expires := greatest(v_now, coalesce(v_user.subscription_expires_at, v_now))
    + make_interval(days => coalesce(v_order.duration_days, CASE WHEN v_order.billing_period = 'annual' THEN 365 ELSE 30 END));

  UPDATE public.owner_subscription_orders
  SET owner_id = p_user_id
  WHERE id = v_order.id AND owner_id IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'SUBSCRIPTION_ALREADY_CLAIMED');
  END IF;

  UPDATE public.users
  SET role = CASE WHEN role IN ('admin', 'co_founder') THEN role ELSE 'owner' END,
      subscription_plan = v_order.plan_code,
      subscription_expires_at = v_expires,
      trial_ends_at = NULL,
      updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.notifications(user_id, title, body, type, is_read, metadata, created_at)
  VALUES (
    p_user_id,
    'تم تفعيل اشتراك Pro',
    format('تم ربط اشتراك Pro المدفوع من الموقع بحسابك بنجاح. تاريخ الانتهاء: %s.', to_char(v_expires at time zone 'Africa/Cairo', 'DD FMMonth YYYY')),
    'subscription_activated',
    false,
    jsonb_build_object('order_id', v_order.id, 'payment_source', v_order.payment_source, 'plan_code', v_order.plan_code, 'gross_amount', v_order.gross_amount),
    v_now
  );

  RETURN jsonb_build_object('success', true, 'order_id', v_order.id, 'plan_code', v_order.plan_code, 'subscription_expires_at', v_expires);
END;
$$;

-- 4. Harden confirm_owner_subscription_payment
CREATE OR REPLACE FUNCTION public.confirm_owner_subscription_payment(
  p_order_id uuid,
  p_paymob_transaction_id text,
  p_gross_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order public.owner_subscription_orders%rowtype;
  v_now timestamptz := now();
  v_expires timestamptz;
  v_claim jsonb;
  v_expected_gross numeric;
  v_matched_user public.users%rowtype;
BEGIN
  SELECT * INTO v_order FROM public.owner_subscription_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND');
  END IF;
  IF v_order.status = 'paid' THEN
    RETURN jsonb_build_object('success', true, 'already_paid', true, 'order_id', p_order_id);
  END IF;
  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_PENDING');
  END IF;

  v_expected_gross := coalesce(v_order.gross_amount, v_order.amount);
  IF abs(coalesce(v_expected_gross, 0) - coalesce(p_gross_amount, 0)) > 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'AMOUNT_MISMATCH');
  END IF;

  UPDATE public.owner_subscription_orders
  SET status = 'paid', paymob_transaction_id = p_paymob_transaction_id, paid_at = v_now
  WHERE id = p_order_id;

  IF v_order.owner_id IS NOT NULL THEN
    v_expires := greatest(v_now, coalesce((SELECT subscription_expires_at FROM public.users WHERE id = v_order.owner_id), v_now))
      + make_interval(days => coalesce(v_order.duration_days, CASE WHEN v_order.billing_period = 'annual' THEN 365 ELSE 30 END));

    UPDATE public.users
    SET role = CASE WHEN role IN ('admin', 'co_founder') THEN role ELSE 'owner' END,
        subscription_plan = v_order.plan_code,
        subscription_expires_at = v_expires,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = v_order.owner_id;

    INSERT INTO public.notifications(user_id, title, body, type, is_read, metadata, created_at)
    VALUES (
      v_order.owner_id,
      'تم تفعيل اشتراك Pro',
      format('تم تأكيد دفع اشتراك Pro بنجاح. تاريخ الانتهاء: %s.', to_char(v_expires at time zone 'Africa/Cairo', 'DD FMMonth YYYY')),
      'subscription_activated',
      false,
      jsonb_build_object('order_id', v_order.id, 'payment_source', v_order.payment_source, 'plan_code', v_order.plan_code, 'gross_amount', v_order.gross_amount, 'paymob_transaction_id', p_paymob_transaction_id),
      v_now
    );
  ELSE
    -- Web payment without pre-bound owner_id:
    SELECT * INTO v_matched_user
    FROM public.users u
    WHERE lower(trim(u.email)) = lower(trim(v_order.checkout_email))
      AND nullif(trim(u.phone), '') IS NOT NULL
      AND nullif(trim(v_order.checkout_phone), '') IS NOT NULL
      AND regexp_replace(u.phone, '[^0-9+]', '', 'g') = regexp_replace(v_order.checkout_phone, '[^0-9+]', '', 'g')
    ORDER BY u.created_at DESC
    LIMIT 1;

    IF FOUND THEN
      -- Only auto-activate if the user is ALREADY an owner.
      -- Never silently convert an existing player to owner from background web payment alone!
      IF v_matched_user.role = 'owner' THEN
        SELECT public.claim_paid_web_subscription_for_user(v_matched_user.id) INTO v_claim;
      ELSIF v_matched_user.role IN ('admin', 'co_founder') THEN
        v_expires := greatest(v_now, coalesce(v_matched_user.subscription_expires_at, v_now))
          + make_interval(days => coalesce(v_order.duration_days, CASE WHEN v_order.billing_period = 'annual' THEN 365 ELSE 30 END));
        UPDATE public.owner_subscription_orders SET owner_id = v_matched_user.id WHERE id = p_order_id;
        UPDATE public.users SET subscription_plan = v_order.plan_code, subscription_expires_at = v_expires, updated_at = v_now WHERE id = v_matched_user.id;
      END IF;
      -- If role is 'player', leave owner_id = null so it must be claimed via verified account claim/signup.
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'already_paid', false, 'order_id', p_order_id,
    'owner_id', (SELECT owner_id FROM public.owner_subscription_orders WHERE id = p_order_id),
    'status', 'paid', 'paid_at', v_now, 'claimed', coalesce(v_claim->>'success', 'false') = 'true'
  );
END;
$$;
