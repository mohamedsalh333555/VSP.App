-- ==============================================================================
-- 🏆 ROLLBACK FOR MIGRATION 202608110003: OPERATIONAL NIGHT SHIFT FIX
-- ==============================================================================

DROP INDEX IF EXISTS public.idx_bookings_operational_date;
ALTER TABLE public.bookings DROP COLUMN IF EXISTS operational_date;
DROP FUNCTION IF EXISTS public.get_operational_date(TIMESTAMPTZ, INT);
