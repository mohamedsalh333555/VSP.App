import sys
from db_client import run_sql

migration_sql = """
-- 1. Create View for courts alias if needed
CREATE OR REPLACE VIEW courts AS 
SELECT * FROM stadiums;

-- 2. Create court_operating_hours table
CREATE TABLE IF NOT EXISTS court_operating_hours (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  court_id UUID NOT NULL REFERENCES stadiums(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  -- 0=الأحد, 1=الاثنين, ..., 6=السبت
  open_time TIME NOT NULL DEFAULT '16:00',
  close_time TIME NOT NULL DEFAULT '02:00',
  is_closed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- index للأداء
CREATE INDEX IF NOT EXISTS idx_court_operating_hours_court_id 
ON court_operating_hours(court_id);

-- RLS
ALTER TABLE court_operating_hours ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'court_operating_hours' AND policyname = 'owner_can_manage_hours'
  ) THEN
    CREATE POLICY "owner_can_manage_hours" ON court_operating_hours
    FOR ALL USING (
      court_id IN (
        SELECT id FROM stadiums WHERE owner_id = auth.uid()
      )
    );
  END IF;
END $$;

-- 3. Unified RPC for owner dashboard analytics
DROP FUNCTION IF EXISTS get_owner_dashboard_analytics;

CREATE OR REPLACE FUNCTION get_owner_dashboard_analytics(
  p_owner_id    UUID,
  p_start_date  TIMESTAMPTZ,
  p_end_date    TIMESTAMPTZ,
  p_court_id    UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result              JSON;
  v_total_op_hours      NUMERIC := 0;
  v_booked_hours        NUMERIC := 0;
  v_total_revenue       NUMERIC := 0;
  v_cash_revenue        NUMERIC := 0;
  v_online_revenue      NUMERIC := 0;
  v_total_bookings      INTEGER := 0;
  v_cash_bookings       INTEGER := 0;
  v_online_bookings     INTEGER := 0;
  v_period_days         INTEGER;
  v_avg_hourly_rate     NUMERIC := 200;
  v_stadium_count       INTEGER := 1;
BEGIN

  -- عدد الأيام في الفترة
  v_period_days := GREATEST(1, DATE_PART('day', p_end_date - p_start_date)::INTEGER);

  -- متوسط سعر الساعة لملاعب المالك
  SELECT COALESCE(AVG(price_per_hour), 200)
  INTO v_avg_hourly_rate
  FROM stadiums
  WHERE owner_id = p_owner_id
    AND (p_court_id IS NULL OR id = p_court_id)
    AND price_per_hour > 0;

  IF v_avg_hourly_rate IS NULL OR v_avg_hourly_rate <= 0 THEN
    v_avg_hourly_rate := 200;
  END IF;

  -- حساب ساعات التشغيل الفعلية خلال الفترة من جدول court_operating_hours
  SELECT COALESCE(SUM(
    CASE
      WHEN oh.close_time > oh.open_time
        THEN EXTRACT(EPOCH FROM (oh.close_time - oh.open_time)) / 3600.0
      ELSE
        EXTRACT(EPOCH FROM ('24:00:00'::TIME - oh.open_time + oh.close_time)) / 3600.0
    END
  ) * v_period_days, 0)
  INTO v_total_op_hours
  FROM court_operating_hours oh
  JOIN stadiums c ON c.id = oh.court_id
  WHERE c.owner_id = p_owner_id
    AND (p_court_id IS NULL OR oh.court_id = p_court_id)
    AND oh.is_closed = FALSE;

  -- لو مفيش ساعات تشغيل معرّفة، افترض 10 ساعات يومياً كـ default معقول لكل ملعب
  IF v_total_op_hours = 0 THEN
    IF p_court_id IS NOT NULL THEN
      v_stadium_count := 1;
    ELSE
      SELECT GREATEST(1, COUNT(*)::INTEGER) 
      INTO v_stadium_count 
      FROM stadiums 
      WHERE owner_id = p_owner_id AND is_deleted_by_owner = FALSE;
    END IF;
    v_total_op_hours := 10.0 * v_period_days * v_stadium_count;
  END IF;

  -- حساب الحجوزات والإيرادات
  SELECT
    COUNT(b.id),
    COUNT(b.id) FILTER (WHERE b.payment_method = 'cash' OR b.payment_source = 'pitch_cash'),
    COUNT(b.id) FILTER (WHERE NOT (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash')),
    COALESCE(SUM(CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END), 0),
    COALESCE(SUM(CASE WHEN (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
                      THEN (CASE WHEN b.total_price > 0 THEN b.total_price ELSE b.deposit_paid END) 
                      ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN NOT (b.payment_method = 'cash' OR b.payment_source = 'pitch_cash') 
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

  -- ضمان التماسك الرياضي التام (total == cash + online دايماً)
  IF (v_total_revenue - (v_cash_revenue + v_online_revenue)) <> 0 THEN
    v_cash_revenue := v_total_revenue - v_online_revenue;
  END IF;

  -- بناء النتيجة JSON
  SELECT json_build_object(

    'meta', json_build_object(
      'start_date',   p_start_date,
      'end_date',     p_end_date,
      'period_days',  v_period_days
    ),

    'revenue', json_build_object(
      'total',            ROUND(v_total_revenue, 2),
      'cash',             ROUND(v_cash_revenue, 2),
      'online',           ROUND(v_online_revenue, 2),
      'cash_percentage',  CASE WHEN v_total_revenue > 0
                            THEN ROUND((v_cash_revenue / v_total_revenue) * 100, 1)
                            ELSE 0 END,
      'online_percentage',CASE WHEN v_total_revenue > 0
                            THEN ROUND((v_online_revenue / v_total_revenue) * 100, 1)
                            ELSE 0 END,
      'unrealized',       ROUND(
                            GREATEST(v_total_op_hours - v_booked_hours, 0) * v_avg_hourly_rate,
                          2)
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
$$;

GRANT EXECUTE ON FUNCTION get_owner_dashboard_analytics(UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated, service_role, anon;
"""

print("Deploying Phase 1 SQL Migration...")
res = run_sql(migration_sql)
print("Migration applied successfully!")
