-- Migration: 20261001250000_owner_financial_ssot_unification.sql
-- Description: Unifies Owner Financial SSOT:
--   1. Removes hardcoded 200 EGP hourly rate fallback and artificial unrealized revenue in get_owner_dashboard_analytics.
--   2. Strict accounting reconciliation: Realized revenue strictly requires completed/no_show with paid verification.
--   3. Guarantees zero artificial revenue when no price or data exists (returns 0, never defaults).
--   4. Preserves get_owner_financial_summary as the sole single source of truth for available payout balance.

CREATE OR REPLACE FUNCTION public.get_owner_dashboard_analytics(
  p_owner_id uuid,
  p_start_date timestamp with time zone,
  p_end_date timestamp with time zone,
  p_court_id uuid DEFAULT NULL::uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_result              JSON;
  v_total_op_hours      NUMERIC := 0;
  v_booked_hours        NUMERIC := 0;
  v_total_revenue       NUMERIC := 0;
  v_cash_revenue        NUMERIC := 0;
  v_online_revenue      NUMERIC := 0;
  v_realized_revenue    NUMERIC := 0;
  v_realized_cash       NUMERIC := 0;
  v_realized_online     NUMERIC := 0;
  v_upcoming_value      NUMERIC := 0;
  v_upcoming_cash       NUMERIC := 0;
  v_upcoming_online     NUMERIC := 0;
  v_total_bookings      INTEGER := 0;
  v_cash_bookings       INTEGER := 0;
  v_online_bookings     INTEGER := 0;
  v_period_days         INTEGER;
  v_avg_hourly_rate     NUMERIC := 0;
BEGIN
  -- Server-side Authentication & Authorization Guard
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED: تسجيل الدخول مطلوب للوصول إلى تحليلات لوحة التحكم.'
      USING ERRCODE = '42501';
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
    IF NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RAISE EXCEPTION 'UNAUTHORIZED: غير مصرح بالوصول إلى بيانات هذا المالك.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- عدد الأيام في الفترة
  v_period_days := GREATEST(1, DATE_PART('day', p_end_date - p_start_date)::INTEGER);

  -- متوسط سعر الساعة لملاعب المالك (Zero-Fallback SSOT: no artificial 200 EGP)
  SELECT COALESCE(AVG(price_per_hour), 0)
  INTO v_avg_hourly_rate
  FROM stadiums
  WHERE owner_id = p_owner_id
    AND (p_court_id IS NULL OR id = p_court_id)
    AND price_per_hour > 0;

  IF v_avg_hourly_rate IS NULL OR v_avg_hourly_rate < 0 THEN
    v_avg_hourly_rate := 0;
  END IF;

  -- حساب ساعات التشغيل الفعلية من ملاعب المالك في جدول stadiums مباشرة (Single Source of Truth)
  SELECT COALESCE(SUM(
    CASE
      -- Calculate raw daily shift hours
      WHEN s.closing_time IS NOT NULL AND s.opening_time IS NOT NULL THEN
        (CASE
          WHEN s.closing_time > s.opening_time THEN
            EXTRACT(EPOCH FROM (s.closing_time - s.opening_time)) / 3600.0
          ELSE
            -- Overnight shift (e.g. 15:00 to 02:00)
            EXTRACT(EPOCH FROM ('24:00:00'::TIME - s.opening_time + s.closing_time)) / 3600.0
        END)
        -- Subtract split shift break if active
        - (CASE
            WHEN s.is_split_shift IS TRUE AND s.break_start_time IS NOT NULL AND s.break_end_time IS NOT NULL THEN
              (CASE
                WHEN s.break_end_time > s.break_start_time THEN
                  EXTRACT(EPOCH FROM (s.break_end_time - s.break_start_time)) / 3600.0
                ELSE
                  EXTRACT(EPOCH FROM ('24:00:00'::TIME - s.break_start_time + s.break_end_time)) / 3600.0
              END)
            ELSE 0.0
          END)
      ELSE 0.0
    END
  ) * v_period_days, 0)
  INTO v_total_op_hours
  FROM public.stadiums s
  WHERE s.owner_id = p_owner_id
    AND (p_court_id IS NULL OR s.id = p_court_id)
    AND COALESCE(s.is_deleted_by_owner, false) = false;

  -- 1. حساب الحجوزات والإيرادات التشغيلية الكلية للفترة (Operational Booking Value)
  SELECT
    COUNT(b.id),
    COUNT(b.id) FILTER (WHERE b.payment_source = 'cash' OR b.payment_method = 'cash'),
    COUNT(b.id) FILTER (WHERE b.payment_source <> 'cash' AND b.payment_method <> 'cash'),
    COALESCE(SUM(CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source = 'cash' OR b.payment_method = 'cash')
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END)
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source <> 'cash' AND b.payment_method <> 'cash')
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END)
                      ELSE 0 END), 0),
    COALESCE(SUM(
      GREATEST(0, EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600.0)
    ), 0)
  INTO
    v_total_bookings,
    v_cash_bookings,
    v_online_bookings,
    v_total_revenue,
    v_cash_revenue,
    v_online_revenue,
    v_booked_hours
  FROM bookings b
  WHERE b.owner_id = p_owner_id
    AND (p_court_id IS NULL OR b.stadium_id = p_court_id)
    AND b.start_time >= p_start_date
    AND b.start_time < p_end_date
    AND b.status IN ('confirmed', 'completed', 'upcoming');

  -- 2. الإيراد المحقق فعلياً (Realized Accounting Revenue: played completed or no-show bookings)
  SELECT
    COALESCE(SUM(
      CASE
        WHEN (b.payment_source = 'cash' OR b.payment_method = 'cash')
          THEN (CASE WHEN (b.payment_status = 'paid' OR b.is_paid = true) THEN b.total_price ELSE GREATEST(b.deposit_paid, 0) END)
        ELSE
          (CASE WHEN (b.payment_status = 'paid' OR b.is_paid = true)
                THEN (CASE WHEN b.deposit_paid > 0 AND b.deposit_paid < b.total_price THEN b.deposit_paid ELSE b.total_price END)
                ELSE 0 END)
      END
    ), 0),
    COALESCE(SUM(
      CASE WHEN (b.payment_source = 'cash' OR b.payment_method = 'cash')
           THEN (CASE WHEN (b.payment_status = 'paid' OR b.is_paid = true) THEN b.total_price ELSE GREATEST(b.deposit_paid, 0) END)
           ELSE 0 END
    ), 0),
    COALESCE(SUM(
      CASE WHEN (b.payment_source <> 'cash' AND b.payment_method <> 'cash' AND (b.payment_status = 'paid' OR b.is_paid = true))
           THEN (CASE WHEN b.deposit_paid > 0 AND b.deposit_paid < b.total_price THEN b.deposit_paid ELSE b.total_price END)
           ELSE 0 END
    ), 0)
  INTO
    v_realized_revenue,
    v_realized_cash,
    v_realized_online
  FROM bookings b
  WHERE b.owner_id = p_owner_id
    AND (p_court_id IS NULL OR b.stadium_id = p_court_id)
    AND b.start_time >= p_start_date
    AND b.start_time < p_end_date
    AND b.status IN ('completed', 'no_show');

  -- 3. قيمة الحجوزات المؤكدة القادمة (Upcoming Confirmed Operational Value: future matches awaiting play)
  SELECT
    COALESCE(SUM(CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source = 'cash' OR b.payment_method = 'cash')
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END)
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_source <> 'cash' AND b.payment_method <> 'cash')
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END)
                      ELSE 0 END), 0)
  INTO
    v_upcoming_value,
    v_upcoming_cash,
    v_upcoming_online
  FROM bookings b
  WHERE b.owner_id = p_owner_id
    AND (p_court_id IS NULL OR b.stadium_id = p_court_id)
    AND b.start_time >= p_start_date
    AND b.start_time < p_end_date
    AND b.status IN ('confirmed', 'upcoming')
    AND b.end_time > now();

  -- ضمان التماسك الرياضي التام (total == cash + online دايماً)
  IF (v_total_revenue - (v_cash_revenue + v_online_revenue)) <> 0 THEN
    v_cash_revenue := v_total_revenue - v_online_revenue;
  END IF;

  -- بناء النتيجة JSON بفصل المحقق عن المتوقع، مع صفر حقيقي عند انعدام السعر (Zero Artificial Fallback)
  SELECT json_build_object(
    'meta', json_build_object(
      'start_date',   p_start_date,
      'end_date',     p_end_date,
      'period_days',  v_period_days
    ),
    'revenue', json_build_object(
      'total',                     ROUND(v_total_revenue, 2),
      'cash',                      ROUND(v_cash_revenue, 2),
      'online',                    ROUND(v_online_revenue, 2),
      'cash_percentage',           CASE WHEN v_total_revenue > 0
                                     THEN ROUND((v_cash_revenue / v_total_revenue) * 100, 1)
                                     ELSE 0 END,
      'online_percentage',         CASE WHEN v_total_revenue > 0
                                     THEN ROUND((v_online_revenue / v_total_revenue) * 100, 1)
                                     ELSE 0 END,
      'realized_revenue',          ROUND(v_realized_revenue, 2),
      'realized_cash',             ROUND(v_realized_cash, 2),
      'realized_online',           ROUND(v_realized_online, 2),
      'upcoming_confirmed_value',  ROUND(v_upcoming_value, 2),
      'upcoming_cash_value',       ROUND(v_upcoming_cash, 2),
      'upcoming_online_value',     ROUND(v_upcoming_online, 2),
      'unrealized',                CASE WHEN v_avg_hourly_rate > 0
                                     THEN ROUND(GREATEST(v_total_op_hours - v_booked_hours, 0) * v_avg_hourly_rate, 2)
                                     ELSE 0 END
    ),
    'bookings', json_build_object(
      'total_count',    v_total_bookings,
      'cash_count',     v_cash_bookings,
      'online_count',   v_online_bookings,
      'average_price',  CASE WHEN v_total_bookings > 0
                          THEN ROUND(v_total_revenue / v_total_bookings, 2)
                          ELSE 0 END
    ),
    'capacity', json_build_object(
      'total_operating_hours', ROUND(v_total_op_hours, 1),
      'booked_hours',          ROUND(v_booked_hours, 1),
      'unbooked_hours',        ROUND(GREATEST(v_total_op_hours - v_booked_hours, 0), 1),
      'occupancy_rate',        CASE WHEN v_total_op_hours > 0
                                 THEN ROUND((v_booked_hours / v_total_op_hours) * 100, 1)
                                 ELSE 0 END
    )
  ) INTO v_result;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_owner_dashboard_analytics(uuid, timestamptz, timestamptz, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_owner_dashboard_analytics(uuid, timestamptz, timestamptz, uuid) TO authenticated, service_role;

-- Record migration in schema_migrations
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261001250000', 'owner_financial_ssot_unification')
ON CONFLICT (version) DO NOTHING;
