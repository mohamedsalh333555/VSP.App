-- ============================================================================
-- VSP MATCHUPS FEATURE (ميزة مواجهات) — SCHEMA, RLS & ZERO-TRUST RPCs
-- Date: 2026-08-30
-- Description:
--   1. Alter teams: active_invite_code, invite_code_expires_at
--   2. Alter bookings: matchup_mode ('duo', 'winner_stays'), matchup_closed_at
--   3. Create matchup_teams table & RLS
--   4. Create matchup_results table & RLS
--   5. Create team_head_to_head table & RLS
--   6. RPC: generate_team_invite_code(p_team_id UUID)
--   7. RPC: add_team_to_matchup_by_code(p_booking_id UUID, p_invite_code TEXT)
--   8. RPC: confirm_matchup_atomic(p_booking_id UUID)
--   9. RPC: record_matchup_result_atomic(p_booking_id UUID, p_team_a_id UUID, p_team_b_id UUID, p_outcome TEXT)
--  10. RPC: close_matchup_atomic(p_booking_id UUID)
--  11. Trigger on matchup_results to auto-update team_head_to_head
--  12. Auto-expire cron job for matchups (> 48h after end_time)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Alter public.teams
-- ----------------------------------------------------------------------------
ALTER TABLE public.teams
ADD COLUMN IF NOT EXISTS active_invite_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS invite_code_expires_at TIMESTAMPTZ;

-- ----------------------------------------------------------------------------
-- 2. Alter public.bookings
-- ----------------------------------------------------------------------------
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS matchup_mode TEXT CHECK (matchup_mode IN ('duo', 'winner_stays') OR matchup_mode IS NULL),
ADD COLUMN IF NOT EXISTS matchup_closed_at TIMESTAMPTZ;

-- ----------------------------------------------------------------------------
-- 3. Create public.matchup_teams
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.matchup_teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    added_by_user_id UUID NOT NULL REFERENCES public.users(id),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(booking_id, team_id)
);

ALTER TABLE public.matchup_teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view matchup teams" ON public.matchup_teams;
CREATE POLICY "Anyone authenticated can view matchup teams"
    ON public.matchup_teams
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Server and booking host can manage matchup teams" ON public.matchup_teams;
CREATE POLICY "Server and booking host can manage matchup teams"
    ON public.matchup_teams
    FOR ALL
    TO authenticated
    USING (
        auth.uid() = added_by_user_id 
        OR EXISTS (
            SELECT 1 FROM public.bookings b 
            WHERE b.id = matchup_teams.booking_id 
            AND (b.created_by_user_id = auth.uid() OR b.user_id = auth.uid())
        )
    );

-- ----------------------------------------------------------------------------
-- 4. Create public.matchup_results
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.matchup_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    team_a_id UUID NOT NULL REFERENCES public.teams(id),
    team_b_id UUID NOT NULL REFERENCES public.teams(id),
    outcome TEXT NOT NULL CHECK (outcome IN ('team_a_win', 'team_b_win', 'draw')),
    recorded_by UUID NOT NULL REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CHECK (team_a_id <> team_b_id)
);

ALTER TABLE public.matchup_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view matchup results" ON public.matchup_results;
CREATE POLICY "Anyone authenticated can view matchup results"
    ON public.matchup_results
    FOR SELECT
    TO authenticated
    USING (true);

-- ----------------------------------------------------------------------------
-- 5. Create public.team_head_to_head
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.team_head_to_head (
    team_a_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    team_b_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    team_a_wins INT NOT NULL DEFAULT 0,
    team_b_wins INT NOT NULL DEFAULT 0,
    draws INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (team_a_id, team_b_id),
    CHECK (team_a_id < team_b_id)
);

ALTER TABLE public.team_head_to_head ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view team head to head" ON public.team_head_to_head;
CREATE POLICY "Anyone authenticated can view team head to head"
    ON public.team_head_to_head
    FOR SELECT
    TO authenticated
    USING (true);

-- ----------------------------------------------------------------------------
-- 6. Trigger Function: sync_head_to_head_on_result_insert
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_head_to_head_on_result_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_first_team UUID;
    v_second_team UUID;
    v_first_wins_inc INT := 0;
    v_second_wins_inc INT := 0;
    v_draws_inc INT := 0;
BEGIN
    IF NEW.team_a_id < NEW.team_b_id THEN
        v_first_team := NEW.team_a_id;
        v_second_team := NEW.team_b_id;
        IF NEW.outcome = 'team_a_win' THEN
            v_first_wins_inc := 1;
        ELSIF NEW.outcome = 'team_b_win' THEN
            v_second_wins_inc := 1;
        ELSE
            v_draws_inc := 1;
        END IF;
    ELSE
        v_first_team := NEW.team_b_id;
        v_second_team := NEW.team_a_id;
        IF NEW.outcome = 'team_b_win' THEN
            v_first_wins_inc := 1;
        ELSIF NEW.outcome = 'team_a_win' THEN
            v_second_wins_inc := 1;
        ELSE
            v_draws_inc := 1;
        END IF;
    END IF;

    INSERT INTO public.team_head_to_head (
        team_a_id,
        team_b_id,
        team_a_wins,
        team_b_wins,
        draws,
        updated_at
    )
    VALUES (
        v_first_team,
        v_second_team,
        v_first_wins_inc,
        v_second_wins_inc,
        v_draws_inc,
        timezone('utc'::text, now())
    )
    ON CONFLICT (team_a_id, team_b_id) DO UPDATE SET
        team_a_wins = public.team_head_to_head.team_a_wins + EXCLUDED.team_a_wins,
        team_b_wins = public.team_head_to_head.team_b_wins + EXCLUDED.team_b_wins,
        draws = public.team_head_to_head.draws + EXCLUDED.draws,
        updated_at = timezone('utc'::text, now());

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_head_to_head ON public.matchup_results;
CREATE TRIGGER trg_sync_head_to_head
    AFTER INSERT ON public.matchup_results
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_head_to_head_on_result_insert();

-- ----------------------------------------------------------------------------
-- 7. RPC: generate_team_invite_code(p_team_id UUID)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_team_invite_code(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_captain_id UUID;
    v_team_name TEXT;
    v_code TEXT;
    v_chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    v_i INT;
    v_exists BOOLEAN;
BEGIN
    -- 1. Authentication Check (Fail-Closed)
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Fetch team info
    SELECT captain_id, name INTO v_captain_id, v_team_name
    FROM public.teams
    WHERE id = p_team_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Team not found with ID: %', p_team_id;
    END IF;

    -- 3. Authorization: Caller must be team captain or admin/co_founder
    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
    IF v_caller_id <> v_captain_id AND v_caller_role NOT IN ('admin', 'co_founder') THEN
        RAISE EXCEPTION 'Forbidden: Only the team captain can generate a matchup invite code';
    END IF;

    -- 4. Generate unique 6-character code
    LOOP
        v_code := '';
        FOR v_i IN 1..6 LOOP
            v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
        END LOOP;

        SELECT EXISTS (
            SELECT 1 FROM public.teams WHERE active_invite_code = v_code
        ) INTO v_exists;

        EXIT WHEN NOT v_exists;
    END LOOP;

    -- 5. Update team with new code and 1-hour expiration (invalidates any old code immediately)
    UPDATE public.teams
    SET active_invite_code = v_code,
        invite_code_expires_at = timezone('utc'::text, now()) + INTERVAL '1 hour'
    WHERE id = p_team_id;

    RETURN jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'team_name', v_team_name,
        'invite_code', v_code,
        'expires_at', (timezone('utc'::text, now()) + INTERVAL '1 hour')
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. RPC: add_team_to_matchup_by_code(p_booking_id UUID, p_invite_code TEXT)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.add_team_to_matchup_by_code(
    p_booking_id UUID,
    p_invite_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_target_team RECORD;
    v_clean_code TEXT := upper(trim(p_invite_code));
    v_current_count INT;
    v_target_members_count INT;
    v_paid_fee_exists BOOLEAN;
BEGIN
    -- 1. Authentication Check (Fail-Closed)
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    IF v_clean_code IS NULL OR length(v_clean_code) < 4 THEN
        RAISE EXCEPTION 'Invalid invite code provided';
    END IF;

    -- 2. Verify Booking Ownership
    SELECT id, created_by_user_id, user_id, status, matchup_closed_at INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator can add teams to the matchup';
    END IF;

    IF v_booking.matchup_closed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot add teams: This matchup is already closed';
    END IF;

    -- 3. Lookup target team by active code & expiration
    SELECT id, name, logo_url, captain_id, invite_code_expires_at INTO v_target_team
    FROM public.teams
    WHERE active_invite_code = v_clean_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invite code';
    END IF;

    IF v_target_team.invite_code_expires_at IS NOT NULL AND v_target_team.invite_code_expires_at < timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'This invite code has expired. Please ask the captain to generate a new one.';
    END IF;

    -- 4. Check minimum 5 players requirement for official registration
    SELECT count(*) INTO v_target_members_count
    FROM public.team_members
    WHERE team_id = v_target_team.id;

    IF v_target_members_count < 5 THEN
        RAISE EXCEPTION 'Team "%" is incomplete (has %/5 members required for Matchups)', v_target_team.name, v_target_members_count;
    END IF;

    -- 5. Verify team is not already added to this booking
    IF EXISTS (
        SELECT 1 FROM public.matchup_teams
        WHERE booking_id = p_booking_id AND team_id = v_target_team.id
    ) THEN
        RAISE EXCEPTION 'Team "%" is already added to this matchup', v_target_team.name;
    END IF;

    -- 6. Count current teams in DB directly (Server-verified)
    SELECT count(*) INTO v_current_count
    FROM public.matchup_teams
    WHERE booking_id = p_booking_id;

    -- 7. Sixth team fee validation (Hard Requirement #7)
    IF v_current_count >= 5 THEN
        SELECT EXISTS (
            SELECT 1 FROM public.transactions
            WHERE booking_id = p_booking_id
            AND transaction_type = 'matchup_extra_teams_fee'
            AND status IN ('paid', 'completed')
        ) INTO v_paid_fee_exists;

        IF NOT v_paid_fee_exists THEN
            RAISE EXCEPTION 'LIMIT_REACHED_EXTRA_FEE_REQUIRED: Adding more than 5 teams requires 25 EGP extra fee';
        END IF;
    END IF;

    -- 8. Add team to matchup
    INSERT INTO public.matchup_teams (
        booking_id,
        team_id,
        added_by_user_id,
        joined_at
    )
    VALUES (
        p_booking_id,
        v_target_team.id,
        v_caller_id,
        timezone('utc'::text, now())
    );

    -- 9. Consume the invite code immediately (one-time use)
    UPDATE public.teams
    SET active_invite_code = NULL,
        invite_code_expires_at = NULL
    WHERE id = v_target_team.id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'team_id', v_target_team.id,
        'team_name', v_target_team.name,
        'logo_url', v_target_team.logo_url,
        'total_teams_now', (v_current_count + 1)
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. RPC: confirm_matchup_atomic(p_booking_id UUID)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_matchup_atomic(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_teams_count INT;
    v_mode TEXT;
BEGIN
    -- 1. Authentication Check
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Verify Booking Ownership
    SELECT id, created_by_user_id, user_id, status INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator can confirm the matchup';
    END IF;

    -- 3. Calculate added teams directly from DB
    SELECT count(*) INTO v_teams_count
    FROM public.matchup_teams
    WHERE booking_id = p_booking_id;

    IF v_teams_count < 2 THEN
        RAISE EXCEPTION 'Cannot confirm matchup: At least 2 teams must be added (Current: %)', v_teams_count;
    END IF;

    -- 4. Automatically determine mode from live teams count
    IF v_teams_count = 2 THEN
        v_mode := 'duo';
    ELSE
        v_mode := 'winner_stays';
    END IF;

    -- 5. Update booking
    UPDATE public.bookings
    SET matchup_mode = v_mode,
        booking_type = 'matchup'
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'teams_count', v_teams_count,
        'matchup_mode', v_mode
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. RPC: record_matchup_result_atomic(...)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_matchup_result_atomic(
    p_booking_id UUID,
    p_team_a_id UUID,
    p_team_b_id UUID,
    p_outcome TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_team_a_valid BOOLEAN;
    v_team_b_valid BOOLEAN;
    v_new_result_id UUID;
BEGIN
    -- 1. Authentication Check (Fail-Closed)
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Verify Booking Ownership (Hard Requirement #5: Host captain ONLY)
    SELECT id, created_by_user_id, user_id, status, matchup_closed_at INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator (host captain) has permission to record match results';
    END IF;

    IF v_booking.matchup_closed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Matchup is closed: Cannot record new results for this booking';
    END IF;

    -- 3. Verify Outcome Format
    IF p_outcome NOT IN ('team_a_win', 'team_b_win', 'draw') THEN
        RAISE EXCEPTION 'Invalid outcome "%". Allowed: team_a_win, team_b_win, draw', p_outcome;
    END IF;

    IF p_team_a_id = p_team_b_id THEN
        RAISE EXCEPTION 'Cannot record match result between the same team';
    END IF;

    -- 4. Verify Both Teams belong to this Matchup Booking
    SELECT EXISTS (
        SELECT 1 FROM public.matchup_teams WHERE booking_id = p_booking_id AND team_id = p_team_a_id
    ) INTO v_team_a_valid;

    SELECT EXISTS (
        SELECT 1 FROM public.matchup_teams WHERE booking_id = p_booking_id AND team_id = p_team_b_id
    ) INTO v_team_b_valid;

    IF NOT v_team_a_valid OR NOT v_team_b_valid THEN
        RAISE EXCEPTION 'Both participating teams must be registered in this matchup';
    END IF;

    -- 5. Insert Result (Triggers sync_head_to_head_on_result_insert automatically)
    INSERT INTO public.matchup_results (
        booking_id,
        team_a_id,
        team_b_id,
        outcome,
        recorded_by,
        created_at
    )
    VALUES (
        p_booking_id,
        p_team_a_id,
        p_team_b_id,
        p_outcome,
        v_caller_id,
        timezone('utc'::text, now())
    )
    RETURNING id INTO v_new_result_id;

    RETURN jsonb_build_object(
        'success', true,
        'result_id', v_new_result_id,
        'booking_id', p_booking_id,
        'team_a_id', p_team_a_id,
        'team_b_id', p_team_b_id,
        'outcome', p_outcome
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 11. RPC: close_matchup_atomic(p_booking_id UUID)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.close_matchup_atomic(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_booking RECORD;
    v_results_count INT;
BEGIN
    -- 1. Authentication Check
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- 2. Verify Booking Ownership
    SELECT id, created_by_user_id, user_id, status, matchup_closed_at INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking not found with ID: %', p_booking_id;
    END IF;

    IF COALESCE(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
        RAISE EXCEPTION 'Forbidden: Only the booking creator can close the matchup';
    END IF;

    -- 3. Hard Requirement #6: Must have at least 1 result recorded before leaving/closing
    SELECT count(*) INTO v_results_count
    FROM public.matchup_results
    WHERE booking_id = p_booking_id;

    IF v_results_count = 0 THEN
        RAISE EXCEPTION 'Cannot close matchup without recording at least one match result';
    END IF;

    -- 4. Close the matchup
    UPDATE public.bookings
    SET matchup_closed_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'closed_at', timezone('utc'::text, now()),
        'total_results_recorded', v_results_count
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 12. Function for Cron / Background Maintenance: auto_expire_matchups()
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_expire_matchups()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_closed_count INT := 0;
BEGIN
    UPDATE public.bookings
    SET matchup_closed_at = timezone('utc'::text, now())
    WHERE matchup_mode IS NOT NULL 
      AND matchup_closed_at IS NULL
      AND (end_time + INTERVAL '48 hours') < timezone('utc'::text, now());
      
    GET DIAGNOSTICS v_closed_count = ROW_COUNT;
    RETURN v_closed_count;
END;
$$;
