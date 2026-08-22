-- ==============================================================================
-- 🛡️ VSP SPORTS PLATFORM — PASS 2: CATEGORY 1 (DATABASE & SECURITY HARDENING)
-- Migration File: supabase/migrations/20260823_pass2_category1_database_and_security_hardening.sql
-- ==============================================================================
-- ⚠️ INSTRUCTIONS FOR EXECUTION:
-- Run this standalone script in your Supabase SQL Editor (Dashboard > SQL Editor).
-- This script hardens RLS, blocks Privilege Escalation via DB Triggers,
-- secures RPC functions with search_path, and adds composite DB indexes.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ HELPER FUNCTION: Check Admin / Co-Founder Role Safely
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_admin_or_founder(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id
      AND role IN ('admin', 'co_founder')
  );
$$;

-- ------------------------------------------------------------------------------
-- 2️⃣ PRIVILEGE ESCALATION SHIELD: Protect `users` Table Sensitive Fields
-- ------------------------------------------------------------------------------
-- Prevents non-admin users from elevating their role, unblocking themselves,
-- resetting no-show count, or modifying fee trackers.

CREATE OR REPLACE FUNCTION public.trg_protect_users_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_caller_role TEXT;
BEGIN
  -- Allow service_role (backend/edge functions) to make any modification
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  v_caller_role := auth.role();
  v_is_admin := public.is_admin_or_founder(auth.uid());

  -- If the caller is NOT an admin, lock sensitive fields to OLD values
  IF NOT v_is_admin THEN
    NEW.role := OLD.role;
    NEW.is_blocked := OLD.is_blocked;
    NEW.cash_booking_banned := OLD.cash_booking_banned;
    NEW.no_show_count := OLD.no_show_count;
    NEW.total_platform_fees := OLD.total_platform_fees;
    NEW.verification_status := OLD.verification_status;
    NEW.trial_ends_at := OLD.trial_ends_at;
    NEW.subscription_expires_at := OLD.subscription_expires_at;
    NEW.completed_online_bookings_count := OLD.completed_online_bookings_count;
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_users_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_users_sensitive_fields
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.trg_protect_users_sensitive_fields();

-- ------------------------------------------------------------------------------
-- 3️⃣ STADIUM INTEGRITY SHIELD: Protect `stadiums` Sensitive Fields
-- ------------------------------------------------------------------------------
-- Prevents stadium owners from self-verifying, unblocking, or inflating ratings.

CREATE OR REPLACE FUNCTION public.trg_protect_stadiums_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  v_is_admin := public.is_admin_or_founder(auth.uid());

  IF NOT v_is_admin THEN
    NEW.is_verified := OLD.is_verified;
    NEW.is_blocked := OLD.is_blocked;
    NEW.rating := OLD.rating;
    NEW.reviews_count := OLD.reviews_count;
    NEW.is_featured := OLD.is_featured;
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_stadiums_sensitive_fields ON public.stadiums;
CREATE TRIGGER trg_protect_stadiums_sensitive_fields
BEFORE UPDATE ON public.stadiums
FOR EACH ROW
EXECUTE FUNCTION public.trg_protect_stadiums_sensitive_fields();

-- ------------------------------------------------------------------------------
-- 4️⃣ TOURNAMENT INTEGRITY SHIELD: Protect `championships` Verification Fields
-- ------------------------------------------------------------------------------
-- Prevents tournament creators from self-approving or bypassing creation fees.

CREATE OR REPLACE FUNCTION public.trg_protect_championships_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  IF auth.role() = 'service_role' THEN
    RETURN NEW;
  END IF;

  v_is_admin := public.is_admin_or_founder(auth.uid());

  IF NOT v_is_admin THEN
    -- If fee was not already paid, owner cannot mark it as paid directly
    IF OLD.creation_fee_paid IS NOT TRUE AND NEW.creation_fee_paid IS TRUE THEN
      NEW.creation_fee_paid := OLD.creation_fee_paid;
    END IF;

    -- If not approved, owner cannot mark it as approved
    IF OLD.is_approved IS NOT TRUE AND NEW.is_approved IS TRUE THEN
      NEW.is_approved := OLD.is_approved;
    END IF;
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_championships_sensitive_fields ON public.championships;
CREATE TRIGGER trg_protect_championships_sensitive_fields
BEFORE UPDATE ON public.championships
FOR EACH ROW
EXECUTE FUNCTION public.trg_protect_championships_sensitive_fields();

-- ------------------------------------------------------------------------------
-- 5️⃣ PAYMENT INTEGRITY SHIELD: Protect `bookings` Online Payment State
-- ------------------------------------------------------------------------------
-- Online payments (Paymob/Card/Wallet) can ONLY be confirmed via Webhook or Service Role.

CREATE OR REPLACE FUNCTION public.trg_protect_bookings_payment_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.role() = 'service_role' OR public.is_admin_or_founder(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Block non-service callers from marking electronic bookings as paid
  IF OLD.is_paid IS NOT TRUE 
     AND NEW.is_paid IS TRUE 
     AND NEW.payment_method IN ('paymob', 'card', 'wallet') 
     AND (NEW.webhook_verified IS NOT TRUE OR NEW.paymob_txn_id IS NULL) THEN
    RAISE EXCEPTION 'Security Alert: Online booking payments cannot be verified directly from client.';
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_bookings_payment_fields ON public.bookings;
CREATE TRIGGER trg_protect_bookings_payment_fields
BEFORE UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.trg_protect_bookings_payment_fields();

-- ------------------------------------------------------------------------------
-- 6️⃣ HARDEN RPCs: Secure Execution Rights & Search Paths
-- ------------------------------------------------------------------------------

-- Ensure webhook RPC is strictly restricted to service_role
REVOKE EXECUTE ON FUNCTION public.process_paymob_webhook FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_paymob_webhook TO service_role;

-- Fix search_path on sensitive procedures to prevent search-path injection
ALTER FUNCTION public.process_paymob_webhook SET search_path = public, pg_temp;
ALTER FUNCTION public.create_booking_atomic SET search_path = public, pg_temp;
ALTER FUNCTION public.delete_user_permanently SET search_path = public, pg_temp;

-- ------------------------------------------------------------------------------
-- 7️⃣ HIGH-PERFORMANCE COMPOSITE DATABASE INDEXES
-- ------------------------------------------------------------------------------
-- Speeds up queries and eliminates N+1 full-table scans across high-traffic tables.

-- Bookings table indexes
CREATE INDEX IF NOT EXISTS idx_bookings_created_by_status 
ON public.bookings(created_by_user_id, status);

CREATE INDEX IF NOT EXISTS idx_bookings_owner_operational 
ON public.bookings(owner_id, operational_date);

CREATE INDEX IF NOT EXISTS idx_bookings_active_stadium_time 
ON public.bookings(stadium_id, start_time, end_time) 
WHERE status != 'cancelled';

-- Tournament matches bracket index
CREATE INDEX IF NOT EXISTS idx_tournament_matches_bracket 
ON public.tournament_matches(championship_id, round_index, match_index);

-- Chat messages fast pagination
CREATE INDEX IF NOT EXISTS idx_chat_messages_conv_created 
ON public.chat_messages(conversation_id, created_at DESC);

-- User notifications unread stream
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
ON public.notifications(user_id, is_read, created_at DESC);

-- Stadium reviews index
CREATE INDEX IF NOT EXISTS idx_reviews_stadium_created 
ON public.reviews(stadium_id, created_at DESC);

-- Reports index
CREATE INDEX IF NOT EXISTS idx_reports_target 
ON public.reports(target_id, target_type);

-- Transactions index
CREATE INDEX IF NOT EXISTS idx_transactions_user_created 
ON public.transactions(user_id, created_at DESC);

-- Team members membership lookup
CREATE INDEX IF NOT EXISTS idx_team_members_lookup 
ON public.team_members(team_id, user_id);

-- ------------------------------------------------------------------------------
-- ✅ END OF PASS 2 CATEGORY 1 MIGRATION
-- ------------------------------------------------------------------------------
