-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110003: OPERATIONAL NIGHT SHIFT DATA MODEL FIX
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_operational_date(
  p_timestamp TIMESTAMPTZ,
  p_shift_start_hour INT DEFAULT 6
)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF EXTRACT(HOUR FROM (p_timestamp AT TIME ZONE 'Africa/Cairo')) < p_shift_start_hour THEN
    RETURN ((p_timestamp AT TIME ZONE 'Africa/Cairo') - INTERVAL '1 day')::DATE;
  ELSE
    RETURN (p_timestamp AT TIME ZONE 'Africa/Cairo')::DATE;
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'operational_date'
  ) THEN
    ALTER TABLE public.bookings ADD COLUMN operational_date DATE GENERATED ALWAYS AS (
      get_operational_date(start_time, 6)
    ) STORED;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bookings_operational_date ON public.bookings(operational_date);
