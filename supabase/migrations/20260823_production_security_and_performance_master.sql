-- ==============================================================================
-- 🏆 VSP SPORTS PLATFORM — PRODUCTION MASTER SECURITY & PERFORMANCE PATCH (2026)
-- File: supabase/migrations/20260823_production_security_and_performance_master.sql
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ FIX RUNTIME CRASH IN ELO TRIGGER (Fix non-existent column "trend" in teams)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    home_elo INT;
    away_elo INT;
    new_home_elo INT;
    new_away_elo INT;
    outcome FLOAT;
BEGIN
    IF NEW.status = 'completed' 
       AND (OLD.status IS DISTINCT FROM 'completed')
       AND NEW.booking_type = 'challenge' 
       AND NEW.final_outcome IS NOT NULL 
       AND COALESCE(NEW.elo_processed, false) = false THEN
        
        SELECT COALESCE(points, 1000) INTO home_elo FROM public.teams WHERE id = NEW.player_team_id;
        SELECT COALESCE(points, 1000) INTO away_elo FROM public.teams WHERE id = NEW.opponent_team_id;

        IF home_elo IS NOT NULL AND away_elo IS NOT NULL THEN
            IF NEW.final_outcome = 'homeWin' THEN outcome := 1.0;
            ELSIF NEW.final_outcome = 'draw' THEN outcome := 0.5;
            ELSE outcome := 0.0;
            END IF;

            new_home_elo := round(home_elo + 32 * (outcome - (1.0 / (1.0 + power(10, (away_elo - home_elo)::float / 400.0)))));
            new_away_elo := round(away_elo + 32 * ((1.0 - outcome) - (1.0 / (1.0 + power(10, (home_elo - away_elo)::float / 400.0)))));

            UPDATE public.teams 
            SET points = GREATEST(0, new_home_elo), 
                matches_played = matches_played + 1,
                wins = wins + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                draws = draws + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = losses + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.player_team_id;

            UPDATE public.teams 
            SET points = GREATEST(0, new_away_elo), 
                matches_played = matches_played + 1,
                wins = wins + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                draws = draws + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = losses + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.opponent_team_id;

            NEW.elo_processed := true;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calculate_elo ON public.bookings;
CREATE TRIGGER trg_calculate_elo
BEFORE UPDATE OF status, final_outcome ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.calculate_elo_on_match_completion();


-- ------------------------------------------------------------------------------
-- 2️⃣ PROTECT BOOKING FINANCIAL & SENSITIVE FIELDS (Prevent Free/Tampered Bookings)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_booking_sensitive_fields()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_role text;
BEGIN
  -- Allow postgres, service_role, and internal webhooks
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  -- Allow Admin and Co-founders
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  -- Block unauthorized direct client changes to financial status & prices
  IF NEW.is_paid IS DISTINCT FROM OLD.is_paid AND NEW.is_paid = true AND OLD.is_paid = false THEN
    RAISE EXCEPTION 'Security Alert: Direct payment state manipulation is prohibited.';
  END IF;

  IF NEW.payment_status IS DISTINCT FROM OLD.payment_status AND NEW.payment_status = 'paid' AND OLD.payment_status != 'paid' THEN
    RAISE EXCEPTION 'Security Alert: Setting payment_status to paid directly is prohibited.';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status = 'confirmed' AND OLD.status = 'pending' AND OLD.payment_method = 'paymob' AND NEW.is_paid = false THEN
    RAISE EXCEPTION 'Security Alert: Unpaid electronic bookings cannot be directly confirmed.';
  END IF;

  IF NEW.total_price IS DISTINCT FROM OLD.total_price THEN
    RAISE EXCEPTION 'Security Alert: Booking total_price cannot be modified directly.';
  END IF;

  IF NEW.deposit_paid IS DISTINCT FROM OLD.deposit_paid THEN
    RAISE EXCEPTION 'Security Alert: Booking deposit_paid cannot be modified directly.';
  END IF;

  IF NEW.refund_amount IS DISTINCT FROM OLD.refund_amount THEN
    RAISE EXCEPTION 'Security Alert: Booking refund_amount cannot be modified directly.';
  END IF;

  IF NEW.platform_fee IS DISTINCT FROM OLD.platform_fee THEN
    RAISE EXCEPTION 'Security Alert: Booking platform_fee cannot be modified directly.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_booking_sensitive_fields ON public.bookings;
CREATE TRIGGER trg_protect_booking_sensitive_fields
BEFORE UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.protect_booking_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 3️⃣ PROTECT CHAMPIONSHIPS SENSITIVE FIELDS (Prevent Self-Approval / Fraud)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_championship_sensitive_fields()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder') THEN
    RETURN NEW;
  END IF;

  IF NEW.is_approved IS DISTINCT FROM OLD.is_approved AND NEW.is_approved = true THEN
    RAISE EXCEPTION 'Security Alert: Championship approval requires admin verification.';
  END IF;

  IF NEW.creation_fee_paid IS DISTINCT FROM OLD.creation_fee_paid AND NEW.creation_fee_paid = true THEN
    RAISE EXCEPTION 'Security Alert: Championship creation fee must be verified via gateway or admin.';
  END IF;

  IF NEW.champion_team_id IS DISTINCT FROM OLD.champion_team_id AND NEW.champion_team_id IS NOT NULL THEN
    RAISE EXCEPTION 'Security Alert: Crowning a tournament champion must be executed via tournament RPC.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_championship_sensitive_fields ON public.championships;
CREATE TRIGGER trg_protect_championship_sensitive_fields
BEFORE UPDATE ON public.championships
FOR EACH ROW
EXECUTE FUNCTION public.protect_championship_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 4️⃣ FIX MISSING WITH CHECK CONSTRAINTS ACROSS RLS POLICIES
-- ------------------------------------------------------------------------------

-- A. stadium_custom_rates
DROP POLICY IF EXISTS "stadium_custom_rates_manage_own" ON public.stadium_custom_rates;
CREATE POLICY "stadium_custom_rates_manage_own" ON public.stadium_custom_rates
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.stadiums
    WHERE stadiums.id = stadium_custom_rates.stadium_id 
      AND (stadiums.owner_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
      ))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.stadiums
    WHERE stadiums.id = stadium_custom_rates.stadium_id 
      AND (stadiums.owner_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
      ))
  )
);

-- B. notifications
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
CREATE POLICY "notifications_update" ON public.notifications
FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- C. tournament_matches
DROP POLICY IF EXISTS "tournament_matches_update" ON public.tournament_matches;
CREATE POLICY "tournament_matches_update" ON public.tournament_matches
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.championships c
    WHERE c.id = tournament_matches.championship_id 
      AND (c.owner_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
      ))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.championships c
    WHERE c.id = tournament_matches.championship_id 
      AND (c.owner_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')
      ))
  )
);

-- D. webhook_logs
DROP POLICY IF EXISTS "webhook_logs_admin_only" ON public.webhook_logs;
CREATE POLICY "webhook_logs_admin_only" ON public.webhook_logs
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role IN ('admin', 'co_founder')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role IN ('admin', 'co_founder')
  )
);


-- ------------------------------------------------------------------------------
-- 5️⃣ DATABASE INDEXES OPTIMIZATION (Drop Duplicate & Add Missing Composite Indexes)
-- ------------------------------------------------------------------------------

-- Drop duplicate index on bookings(stadium_id)
DROP INDEX IF EXISTS public.idx_bookings_stadium_id;

-- Fix broken index on tournament_matches (replace non-existent submitted_at with scheduled_time)
DROP INDEX IF EXISTS public.idx_tournament_matches_status_date;
CREATE INDEX IF NOT EXISTS idx_tournament_matches_status_scheduled 
ON public.tournament_matches(status, scheduled_time);

-- Composite index for fast user unread notifications querying
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
ON public.notifications(user_id, is_read, created_at DESC);

-- Composite index for active bookings date search
CREATE INDEX IF NOT EXISTS idx_bookings_status_endtime 
ON public.bookings(status, end_time);

-- Composite index for team active matches query
CREATE INDEX IF NOT EXISTS idx_bookings_player_team_status 
ON public.bookings(player_team_id, status);

CREATE INDEX IF NOT EXISTS idx_bookings_opponent_team_status 
ON public.bookings(opponent_team_id, status);
