-- ==============================================================================
-- 1. Item 2A: Update check constraint to allow 'expired' and schedule pg_cron
-- ==============================================================================
ALTER TABLE public.vsp_1v1_tournament_orders 
DROP CONSTRAINT IF EXISTS vsp_1v1_tournament_orders_payment_status_check;

ALTER TABLE public.vsp_1v1_tournament_orders 
ADD CONSTRAINT vsp_1v1_tournament_orders_payment_status_check
CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded', 'failed_over_capacity', 'refund_failed_manual_review', 'expired'));

-- Function to safely expire pending orders
CREATE OR REPLACE FUNCTION public.auto_expire_pending_1v1_orders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count INT := 0;
BEGIN
  UPDATE public.vsp_1v1_tournament_orders
  SET payment_status = 'expired',
      updated_at = timezone('utc'::text, now())
  WHERE payment_status = 'pending'
    AND expires_at < timezone('utc'::text, now())
    AND expires_at IS NOT NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'expired_count', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_expire_pending_1v1_orders() TO authenticated, service_role, postgres;

-- Schedule cron job if pg_cron exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('expire-pending-1v1-orders')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire-pending-1v1-orders');

    PERFORM cron.schedule(
      'expire-pending-1v1-orders',
      '*/10 * * * *',
      'SELECT public.auto_expire_pending_1v1_orders();'
    );
  END IF;
END $$;

-- ==============================================================================
-- 2. Item 2D: Add prize delivery details to vsp_1v1_tournaments
-- ==============================================================================
ALTER TABLE public.vsp_1v1_tournaments
ADD COLUMN IF NOT EXISTS prize_delivery_details TEXT,
ADD COLUMN IF NOT EXISTS prize_delivery_scheduled_at TIMESTAMPTZ;

-- ==============================================================================
-- 3. Item 2B: Audit log table for match score edits
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.match_score_edits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  match_id UUID NOT NULL,
  championship_id UUID NOT NULL,
  old_score_home INTEGER,
  old_score_away INTEGER,
  old_penalties_home INTEGER,
  old_penalties_away INTEGER,
  new_score_home INTEGER NOT NULL,
  new_score_away INTEGER NOT NULL,
  new_penalties_home INTEGER,
  new_penalties_away INTEGER,
  edited_by UUID NOT NULL REFERENCES auth.users(id),
  edit_reason TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.match_score_edits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner_can_insert_edits" ON public.match_score_edits;
CREATE POLICY "owner_can_insert_edits" ON public.match_score_edits
FOR INSERT WITH CHECK (
  edited_by = auth.uid()
);

DROP POLICY IF EXISTS "owner_can_read_own_edits" ON public.match_score_edits;
CREATE POLICY "owner_can_read_own_edits" ON public.match_score_edits
FOR SELECT USING (
  championship_id IN (
    SELECT id FROM public.championships WHERE owner_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin')
  )
);

-- ==============================================================================
-- 4. Item 2C: Add forfeit support to tournament_matches
-- ==============================================================================
ALTER TABLE public.tournament_matches
ADD COLUMN IF NOT EXISTS is_forfeit BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS forfeit_team_id UUID;

-- ==============================================================================
-- 5. Item 2E: Settings table for team league fee & configs
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.league_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

INSERT INTO public.league_settings (setting_key, setting_value, description)
VALUES ('team_league_entry_fee', '30', 'رسوم تنظيم الدوري للفرق بالجنيه المصري')
ON CONFLICT (setting_key) DO NOTHING;

ALTER TABLE public.league_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read on league_settings" ON public.league_settings;
CREATE POLICY "Allow public read on league_settings"
ON public.league_settings FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Allow admins to manage league_settings" ON public.league_settings;
CREATE POLICY "Allow admins to manage league_settings"
ON public.league_settings FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin')
  )
);
