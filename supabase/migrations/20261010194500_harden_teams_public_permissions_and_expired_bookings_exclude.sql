-- Migration: Restrict teams_public view to authenticated users only
-- and update exclude_overlapping_stadium_bookings constraint to ignore expired bookings

REVOKE ALL ON public.teams_public FROM anon, authenticated;
GRANT SELECT ON public.teams_public TO authenticated;

ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS exclude_overlapping_stadium_bookings;
ALTER TABLE public.bookings ADD CONSTRAINT exclude_overlapping_stadium_bookings 
EXCLUDE USING gist (stadium_id WITH =, tstzrange(start_time, end_time) WITH &&) 
WHERE (status NOT IN ('cancelled', 'expired'));
