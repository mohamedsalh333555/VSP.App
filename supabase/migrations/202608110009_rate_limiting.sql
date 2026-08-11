-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110009: SLIDING-WINDOW RATE LIMITING
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.rate_limit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  action TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_user_action 
ON public.rate_limit_logs(user_id, action, created_at);

-- Function: Check rate limit (Returns TRUE if allowed, FALSE if rate limit exceeded)
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id UUID,
  p_action TEXT,
  p_max_requests INT DEFAULT 5,
  p_window_seconds INT DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INT;
BEGIN
  -- Clean up old entries
  DELETE FROM public.rate_limit_logs
  WHERE created_at < NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  -- Count recent requests for this user & action
  SELECT COUNT(*) INTO v_count
  FROM public.rate_limit_logs
  WHERE user_id = p_user_id
    AND action = p_action
    AND created_at >= NOW() - (p_window_seconds || ' seconds')::INTERVAL;

  IF v_count >= p_max_requests THEN
    RETURN FALSE; // Rate limit exceeded!
  END IF;

  -- Record request
  INSERT INTO public.rate_limit_logs (user_id, action, created_at)
  VALUES (p_user_id, p_action, NOW());

  RETURN TRUE;
END;
$$;
