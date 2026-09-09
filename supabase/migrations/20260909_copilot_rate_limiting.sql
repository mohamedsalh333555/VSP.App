-- ==============================================================================
-- 🔒 VSP MIGRATION 20260909: COPILOT & GENERAL SLIDING-WINDOW RATE LIMITING
-- Description: Sliding-window rate limiter table and function for Copilot & APIs.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.rate_limit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  action TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_user_action 
ON public.rate_limit_logs(user_id, action, created_at);

ALTER TABLE public.rate_limit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rate_limit_admin_manage ON public.rate_limit_logs;
CREATE POLICY rate_limit_admin_manage ON public.rate_limit_logs
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
  )
);

-- Function: Check rate limit (Returns TRUE if allowed, FALSE if rate limit exceeded)
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id UUID,
  p_action TEXT,
  p_max_requests INT DEFAULT 10,
  p_window_seconds INT DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count INT;
BEGIN
  -- 1. 🔒 Transaction-scoped advisory lock using native two-key integer signature (classid, objid)
  -- Completely serializes concurrent calls for the exact (user + action) with zero cross-action contention
  PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text), hashtext(p_action));

  -- 2. Fast index-backed cleanup strictly for this user and action
  DELETE FROM public.rate_limit_logs
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at < NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- 3. Count recent requests within the sliding window
  SELECT COUNT(*) INTO v_count
  FROM public.rate_limit_logs
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at >= NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- 4. Reject if limit reached
  IF v_count >= p_max_requests THEN
    RETURN FALSE;
  END IF;

  -- 5. Record new request atomically inside the lock
  INSERT INTO public.rate_limit_logs (user_id, action, created_at)
  VALUES (p_user_id, p_action, NOW());

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_rate_limit(UUID, TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(UUID, TEXT, INT, INT) TO service_role;
