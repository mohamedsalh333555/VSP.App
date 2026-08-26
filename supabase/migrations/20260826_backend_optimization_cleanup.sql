-- Migration: 20260826_backend_optimization_cleanup.sql

-- 1. Unique index on reviews (stadium_id, user_id)
CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_unique_stadium_user 
ON public.reviews (stadium_id, user_id);

-- 2. Clean up redundant duplicate admin policies
DROP POLICY IF EXISTS "Admins can view all bookings" ON public.bookings;
DROP POLICY IF EXISTS "stadiums_admin_manage" ON public.stadiums;

-- 3. Clean up duplicate trigger on championships
DROP TRIGGER IF EXISTS trg_protect_championships_sensitive_fields ON public.championships;
DROP FUNCTION IF EXISTS public.trg_protect_championships_sensitive_fields();

-- 4. Ensure notifications select policy exists for authenticated users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'notifications' AND policyname = 'notifications_select_own'
  ) THEN
    CREATE POLICY notifications_select_own ON public.notifications 
    FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;
