-- ============================================================================
-- VSP Competitive Reward Notifications (Idempotent) & ROI Analytics RPC
-- ============================================================================

-- 1. Idempotent Notification Helper for Competitive Ranking & Reward Events
CREATE OR REPLACE FUNCTION public.vsp_emit_competitive_reward_notification(
  p_user_id UUID,
  p_event_type TEXT,
  p_dedupe_key TEXT,
  p_title TEXT,
  p_body TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF p_user_id IS NULL OR btrim(COALESCE(p_dedupe_key, '')) = '' THEN
    RETURN FALSE;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = p_user_id
      AND type = p_event_type
      AND title = p_title
      AND body = p_body
      AND created_at > now() - interval '24 hours'
  ) THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, created_at)
  VALUES (p_user_id, p_title, p_body, p_event_type, now());

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.vsp_emit_competitive_reward_notification(UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- 2. Admin-only Competitive Rewards & Incremental ROI Analytics (uses VSP commission, NOT gross)
CREATE OR REPLACE FUNCTION public.get_competitive_rewards_analytics(
  p_governorate TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_active_teams       INT := 0;
  v_competitive_matches INT := 0;
  v_paid_bookings      INT := 0;
  v_vsp_commission_egp NUMERIC := 0;
  v_cash_awards_egp    NUMERIC := 0;
  v_free_hours_issued  INT := 0;
  v_free_hours_redeemed INT := 0;
BEGIN
  IF auth.uid() IS NOT NULL THEN
    PERFORM public.require_active_admin_actor();
  END IF;

  SELECT COUNT(DISTINCT r.team_id)::INT, COALESCE(SUM(r.matches_played), 0)::INT
  INTO v_active_teams, v_competitive_matches
  FROM public.team_monthly_rankings r
  WHERE p_governorate IS NULL OR lower(btrim(r.governorate)) = lower(btrim(p_governorate));

  SELECT COUNT(*)::INT, COALESCE(SUM(COALESCE(b.total_vsp_commission, b.vsp_commission, 0)), 0)
  INTO v_paid_bookings, v_vsp_commission_egp
  FROM public.bookings b
  WHERE b.payment_status = 'paid';

  SELECT
    COALESCE(SUM(CASE WHEN reward_type = 'cash' AND status <> 'revoked' THEN cash_amount_egp ELSE 0 END), 0),
    COUNT(*) FILTER (WHERE reward_type = 'free_hour')::INT,
    COUNT(*) FILTER (WHERE reward_type = 'free_hour' AND status = 'redeemed')::INT
  INTO v_cash_awards_egp, v_free_hours_issued, v_free_hours_redeemed
  FROM public.season_reward_entitlements
  WHERE p_governorate IS NULL OR lower(btrim(governorate)) = lower(btrim(p_governorate));

  RETURN jsonb_build_object(
    'success', true,
    'active_teams', v_active_teams,
    'competitive_matches', v_competitive_matches,
    'paid_bookings', v_paid_bookings,
    'vsp_commission_egp', v_vsp_commission_egp,
    'cash_awards_committed_egp', v_cash_awards_egp,
    'free_hours_issued', v_free_hours_issued,
    'free_hours_redeemed', v_free_hours_redeemed
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_competitive_rewards_analytics(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_competitive_rewards_analytics(TEXT) TO authenticated;
