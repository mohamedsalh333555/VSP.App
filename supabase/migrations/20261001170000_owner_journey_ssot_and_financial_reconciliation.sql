-- Migration: 20261001170000_owner_journey_ssot_and_financial_reconciliation.sql
-- Description:
--   1. Subscription & Stadium Limits SSOT:
--      - Unifies stadium limits into ONE authoritative trigger (vsp_guard_stadium_owner_rules).
--      - Establishes canonical 365-day free trial fallback matching subscription_plans.
--      - Drops conflicting duplicate trigger trg_enforce_owner_stadium_limit.
--   2. Owner Onboarding Consistency:
--      - submit_owner_verification checks real stadium existence rather than blind true.
--   3. Financial Reconciliation SSOT:
--      - get_owner_financial_summary adopts the EXACT same formula for available_balance as request_owner_payout_settlement_atomic.
--      - Separates realized_online_revenue (completed/no_show) from upcoming_online_revenue (confirmed).

-- -----------------------------------------------------------------------------
-- 1. UNIFIED STADIUM LIMIT & SENSITIVE FIELD GUARD (ONE TRIGGER TO RULE THEM ALL)
-- -----------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_enforce_owner_stadium_limit ON public.stadiums;
DROP FUNCTION IF EXISTS public.check_owner_stadium_limit_trigger();

CREATE OR REPLACE FUNCTION public.vsp_guard_stadium_owner_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner              public.users%ROWTYPE;
  v_allowed_count      integer := 0;
  v_active_count       integer := 0;
  v_caller             uuid := auth.uid();
  v_is_active_trial    boolean := false;
  v_is_sub_active      boolean := false;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.owner_id IS NULL THEN
      RAISE EXCEPTION 'stadium_owner_required';
    END IF;

    -- Concurrency lock on owner record
    PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;

    SELECT * INTO v_owner
    FROM public.users
    WHERE id = NEW.owner_id;

    IF v_owner.id IS NULL THEN
      RAISE EXCEPTION 'invalid_stadium_owner: مالك الملعب المحدد غير موجود.';
    END IF;

    -- Admins and co-founders bypass limits
    IF v_owner.role IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      NEW.is_verified := COALESCE(NEW.is_verified, false);
      RETURN NEW;
    END IF;

    -- Authoritative 365-day Free Trial SSOT
    v_is_active_trial := (
      COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
      (
        (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
        (v_owner.trial_ends_at IS NULL AND v_owner.created_at + INTERVAL '365 days' > NOW())
      )
    );

    -- Authoritative Paid Subscription Active Check
    v_is_sub_active := (
      v_owner.subscription_expires_at IS NOT NULL AND v_owner.subscription_expires_at > NOW()
    );

    -- Canonical Plan Stadium Limits
    IF v_owner.subscription_plan = 'pro' AND v_is_sub_active THEN
      v_allowed_count := 3;
    ELSIF (v_owner.subscription_plan = 'basic' AND v_is_sub_active) OR v_is_active_trial THEN
      v_allowed_count := 1;
    ELSE
      v_allowed_count := 0;
    END IF;

    -- Count existing active (non-soft-deleted) stadiums
    SELECT count(*) INTO v_active_count
    FROM public.stadiums
    WHERE owner_id = NEW.owner_id
      AND COALESCE(is_deleted_by_owner, false) = false;

    IF v_active_count >= v_allowed_count THEN
      IF v_allowed_count = 0 THEN
        RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: انتهت صلاحية باقة الاشتراك الخاصة بك. يرجى تجديد الاشتراك لإضافة ملاعب.'
          USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
      ELSE
        RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: وصلت للحد الأقصى للملاعب في باقتك الحالية (% ملعب). يرجى الترقية لإضافة ملاعب أخرى.', v_allowed_count
          USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
      END IF;
    END IF;

    NEW.is_verified := false;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF v_caller = OLD.owner_id AND NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
      RAISE EXCEPTION 'owner_cannot_reassign_stadium: لا يمكن نقل ملكية الملعب لمستخدم آخر.';
    END IF;

    -- Reset verification if stadium critical specs changed by owner
    IF v_caller = OLD.owner_id THEN
      IF NEW.name IS DISTINCT FROM OLD.name
         OR NEW.location IS DISTINCT FROM OLD.location
         OR NEW.governorate IS DISTINCT FROM OLD.governorate
         OR NEW.price_per_hour IS DISTINCT FROM OLD.price_per_hour
         OR NEW.base_price IS DISTINCT FROM OLD.base_price
         OR NEW.players_per_team IS DISTINCT FROM OLD.players_per_team
         OR NEW.total_field_capacity IS DISTINCT FROM OLD.total_field_capacity
         OR NEW.opening_time IS DISTINCT FROM OLD.opening_time
         OR NEW.closing_time IS DISTINCT FROM OLD.closing_time
         OR NEW.needs_deposit IS DISTINCT FROM OLD.needs_deposit
         OR NEW.deposit_amount IS DISTINCT FROM OLD.deposit_amount
         OR NEW.images IS DISTINCT FROM OLD.images
         OR NEW.image_url IS DISTINCT FROM OLD.image_url
         OR NEW.features IS DISTINCT FROM OLD.features
         OR NEW.lat IS DISTINCT FROM OLD.lat
         OR NEW.lng IS DISTINCT FROM OLD.lng THEN
        NEW.is_verified := false;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

-- Ensure trigger exists exactly once on public.stadiums
DROP TRIGGER IF EXISTS trg_vsp_guard_stadium_owner_rules ON public.stadiums;
CREATE TRIGGER trg_vsp_guard_stadium_owner_rules
  BEFORE INSERT OR UPDATE ON public.stadiums
  FOR EACH ROW
  EXECUTE FUNCTION public.vsp_guard_stadium_owner_rules();

-- -----------------------------------------------------------------------------
-- 2. UPDATE VIEW owner_subscription_status WITH 365-DAY TRIAL SSOT
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.owner_subscription_status AS
SELECT id,
       name,
       phone,
       verification_status,
       subscription_plan,
       trial_ends_at,
       subscription_expires_at,
       total_platform_fees,
       CASE
           WHEN (subscription_plan = ANY (ARRAY['basic'::text, 'pro'::text])) AND (subscription_expires_at > now()) THEN 'active_paid'::text
           WHEN (COALESCE(subscription_plan, 'free_trial'::text) = 'free_trial'::text) AND (COALESCE(trial_ends_at, created_at + INTERVAL '365 days') > now()) THEN 'active_trial'::text
           ELSE 'expired'::text
       END AS effective_status,
       CASE
           WHEN subscription_plan = 'pro'::text AND subscription_expires_at > now() THEN 3
           WHEN subscription_plan = 'basic'::text AND subscription_expires_at > now() THEN 1
           WHEN (COALESCE(subscription_plan, 'free_trial'::text) = 'free_trial'::text) AND (COALESCE(trial_ends_at, created_at + INTERVAL '365 days') > now()) THEN 1
           ELSE 0
       END AS max_stadiums_allowed
FROM public.users u
WHERE role = 'owner'::text;

-- -----------------------------------------------------------------------------
-- 3. ONBOARDING CONSISTENCY: submit_owner_verification
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.submit_owner_verification(
  p_owner_id uuid DEFAULT NULL,
  p_additional_data jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid         uuid := COALESCE(p_owner_id, auth.uid());
  v_has_stadium boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Owner ID required');
  END IF;

  IF auth.role() <> 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
    IF v_uid IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  -- Check authoritative existence of active stadium
  SELECT EXISTS (
    SELECT 1 FROM public.stadiums 
    WHERE owner_id = v_uid AND COALESCE(is_deleted_by_owner, false) = false
  ) INTO v_has_stadium;

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET verification_status = 'pending',
      is_registration_complete = true,
      has_stadium = v_has_stadium,
      additional_data = COALESCE(additional_data, '{}'::jsonb) || COALESCE(p_additional_data, '{}'::jsonb),
      updated_at = now()
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'has_stadium', v_has_stadium,
    'message', 'Owner verification submitted successfully'
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. FINANCIAL SUMMARY RECONCILIATION: get_owner_financial_summary
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role            text;
  v_stadium_count          int:=0;
  v_total_bookings         int:=0;
  v_realized_online_rev    numeric:=0;
  v_upcoming_online_rev    numeric:=0;
  v_total_platform_fees    numeric:=0;
  v_online_count           int:=0;
  v_cash_revenue           numeric:=0;
  v_cash_collected         numeric:=0;
  v_cash_outstanding       numeric:=0;
  v_cash_bookings          int:=0;
  v_total_withdrawn        numeric:=0;
  v_pending_payouts        numeric:=0;
  v_available_balance      numeric:=0;
  v_cash_debt              numeric:=0;
  v_debt_limit             numeric:=0;
  v_debt_blocked           boolean:=false;
  v_now                    timestamptz:=now();
BEGIN
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres','service_role') THEN
    RETURN jsonb_build_object('success',false,'error','Authentication required');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid()<>p_owner_id AND current_user NOT IN ('postgres','service_role') THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id=auth.uid();
    IF COALESCE(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object('success',false,'error','Unauthorized access to financial records');
    END IF;
  END IF;

  SELECT count(*)::int INTO v_stadium_count
  FROM public.stadiums
  WHERE owner_id=p_owner_id AND COALESCE(is_deleted_by_owner,false)=false;

  -- 1. Realized Online Revenue (EXACT formula used by request_owner_payout_settlement_atomic)
  -- Strictly includes played matches (completed or no_show) that are paid
  SELECT COALESCE(SUM(CASE WHEN COALESCE(b.deposit_paid,0)>0 AND COALESCE(b.deposit_paid,0)<b.total_price THEN b.deposit_paid ELSE b.total_price END),0),
         COALESCE(SUM(COALESCE(b.platform_fee,0)),0),
         count(*)::int
  INTO v_realized_online_rev, v_total_platform_fees, v_online_count
  FROM public.bookings b
  WHERE b.owner_id=p_owner_id
    AND lower(COALESCE(b.payment_method,''))<>'cash'
    AND (b.payment_status='paid' OR b.is_paid=true)
    AND b.status IN ('completed','no_show');

  -- 2. Upcoming Online Revenue (Confirmed future matches awaiting execution)
  SELECT COALESCE(SUM(CASE WHEN COALESCE(b.deposit_paid,0)>0 AND COALESCE(b.deposit_paid,0)<b.total_price THEN b.deposit_paid ELSE b.total_price END),0)
  INTO v_upcoming_online_rev
  FROM public.bookings b
  WHERE b.owner_id=p_owner_id
    AND lower(COALESCE(b.payment_method,''))<>'cash'
    AND (b.payment_status='paid' OR b.is_paid=true)
    AND b.status IN ('confirmed','upcoming')
    AND b.end_time > v_now;

  -- 3. Cash Bookings Calculations
  SELECT COALESCE(SUM(greatest(COALESCE(b.deposit_paid,0),0)),0),
         COALESCE(SUM(CASE WHEN (b.payment_status='paid' OR b.is_paid=true) THEN b.total_price ELSE greatest(COALESCE(b.deposit_paid,0),0) END),0),
         count(*)::int
  INTO v_cash_collected, v_cash_revenue, v_cash_bookings
  FROM public.bookings b
  WHERE b.owner_id=p_owner_id
    AND lower(COALESCE(b.payment_method,''))='cash'
    AND b.status<>'cancelled';

  -- 4. Outstanding Cash for upcoming matches
  SELECT COALESCE(SUM(greatest(COALESCE(b.total_price,0)-greatest(COALESCE(b.deposit_paid,0),0),0)),0)
  INTO v_cash_outstanding
  FROM public.bookings b
  WHERE b.owner_id=p_owner_id
    AND lower(COALESCE(b.payment_method,''))='cash'
    AND b.status IN ('confirmed','partially_paid','pending')
    AND b.end_time > v_now;

  SELECT count(*)::int INTO v_total_bookings
  FROM public.bookings
  WHERE owner_id=p_owner_id AND status<>'cancelled';

  -- 5. Settlements and Authoritative Available Balance
  SELECT COALESCE(SUM(amount),0) INTO v_total_withdrawn
  FROM public.payout_settlements
  WHERE owner_id=p_owner_id AND status='completed';

  SELECT COALESCE(SUM(amount),0) INTO v_pending_payouts
  FROM public.payout_settlements
  WHERE owner_id=p_owner_id AND status IN ('pending','approved');

  -- Mathematically identical to request_owner_payout_settlement_atomic
  v_available_balance := GREATEST(0, v_realized_online_rev - v_total_withdrawn - v_pending_payouts);

  SELECT COALESCE(accumulated_cash_debt,0), COALESCE(debt_limit,0), COALESCE(is_debt_blocked,false)
  INTO v_cash_debt, v_debt_limit, v_debt_blocked
  FROM public.users
  WHERE id=p_owner_id;

  RETURN jsonb_build_object(
    'success',                  true,
    'owner_id',                 p_owner_id,
    'stadium_count',            v_stadium_count,
    'total_bookings_count',     v_total_bookings,
    'realized_online_revenue',  round(v_realized_online_rev, 2),
    'upcoming_online_revenue',  round(v_upcoming_online_rev, 2),
    'online_collected_revenue', round(v_realized_online_rev + v_upcoming_online_rev, 2),
    'net_online_earnings',      round(v_realized_online_rev, 2),
    'owner_online_earnings',    round(v_realized_online_rev, 2),
    'total_platform_fees',      round(v_total_platform_fees, 2),
    'total_withdrawn',          round(v_total_withdrawn, 2),
    'pending_payouts',          round(v_pending_payouts, 2),
    'available_balance',        round(v_available_balance, 2),
    'cash_revenue',             round(v_cash_revenue, 2),
    'cash_collected',           round(v_cash_collected, 2),
    'cash_outstanding',         round(v_cash_outstanding, 2),
    'cash_bookings_count',      v_cash_bookings,
    'online_bookings_count',    v_online_count,
    'accumulated_cash_debt',    round(v_cash_debt, 2),
    'debt_limit',               round(v_debt_limit, 2),
    'is_debt_blocked',          v_debt_blocked
  );
END;
$$;
