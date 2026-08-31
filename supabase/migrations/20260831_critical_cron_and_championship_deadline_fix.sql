-- ==============================================================================
-- VSP MIGRATION 20260831_critical_cron_and_championship_deadline_fix.sql
-- FIX 1: auto_expire_pending_locks() scheduled via pg_cron every 2 minutes
-- FIX 2: join_championship_atomic checks registration_deadline before accepting
-- Date: 2026-08-31
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- FIX 1: Update auto_expire_pending_locks to handle locked_until correctly
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.auto_expire_pending_locks()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_expired_count INT;
BEGIN
    WITH updated AS (
        UPDATE public.bookings
        SET
            status              = 'cancelled',
            cancellation_reason = 'Payment session expired (auto-system)',
            updated_at          = NOW()
        WHERE
            status  = 'pending'
            AND is_paid = FALSE
            AND (
                (locked_until IS NOT NULL AND locked_until < NOW())
                OR
                (locked_until IS NULL AND created_at + INTERVAL '5 minutes' < NOW())
            )
        RETURNING id
    )
    SELECT COUNT(*) INTO v_expired_count FROM updated;
    RETURN v_expired_count;
END;
$function$;

-- Remove old cron jobs before scheduling
DO $$
BEGIN
    BEGIN PERFORM cron.unschedule('expire-pending-locks'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM cron.unschedule('auto-expire-pending-locks'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM cron.unschedule('expire-pending-bookings-5m'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM cron.unschedule('vsp-expire-pending-locks'); EXCEPTION WHEN OTHERS THEN NULL; END;
END$$;

SELECT cron.schedule(
    'vsp-expire-pending-locks',
    '*/2 * * * *',
    $$ SELECT public.auto_expire_pending_locks(); $$
);

-- ==============================================================================
-- FIX 2: join_championship_atomic with registration_deadline check
-- ==============================================================================

DROP FUNCTION IF EXISTS public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC);

CREATE OR REPLACE FUNCTION public.join_championship_atomic(
    p_championship_id UUID,
    p_team_id UUID,
    p_is_paid BOOLEAN DEFAULT false,
    p_player_ids UUID[] DEFAULT ARRAY[]::UUID[],
    p_guest_names TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_total_paid_amount NUMERIC DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_team RECORD;
    v_joined_count INT;
    v_caller_role TEXT;
    v_is_paid_result BOOLEAN := false;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF auth.uid() IS NULL AND (COALESCE(auth.role(), '') != 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول اولا للانضمام للبطولة.');
    END IF;

    SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'انتهى التسجيل في هذه البطولة او انها لم تبدا بعد.');
    END IF;

    -- FIX: Check registration_deadline
    IF v_champ.registration_deadline IS NOT NULL
       AND v_now > v_champ.registration_deadline
       AND COALESCE(auth.role(), '') != 'service_role'
    THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_champ.owner_id IS DISTINCT FROM auth.uid())
           AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')
        THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'انتهت فترة التسجيل في هذه البطولة. لا يمكن اضافة فرق جديدة.'
            );
        END IF;
    END IF;

    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'الفريق غير موجود.');
    END IF;

    IF COALESCE(auth.role(), '') != 'service_role' THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (v_team.captain_id IS DISTINCT FROM auth.uid())
           AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder'))
           AND (v_champ.owner_id IS DISTINCT FROM auth.uid())
        THEN
            RETURN jsonb_build_object('success', false, 'error', 'فقط كابتن الفريق او منظم البطولة يمكنه تسجيل الفريق.');
        END IF;
    END IF;

    IF p_team_id = ANY(COALESCE(v_champ.joined_teams, ARRAY[]::UUID[])) THEN
        RETURN jsonb_build_object('success', false, 'error', 'هذا الفريق مسجل في البطولة بالفعل.');
    END IF;

    v_joined_count := COALESCE(array_length(v_champ.joined_teams, 1), 0);
    IF v_joined_count >= v_champ.max_teams THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة مكتملة العدد. لا يمكن اضافة فرق جديدة.');
    END IF;

    IF COALESCE(auth.role(), '') = 'service_role' THEN
        v_is_paid_result := true;
    ELSIF v_champ.owner_id = auth.uid() OR COALESCE(v_caller_role, '') IN ('admin', 'co_founder') THEN
        v_is_paid_result := true;
    ELSIF COALESCE(v_champ.entry_fee, 0) = 0 THEN
        v_is_paid_result := true;
    ELSE
        v_is_paid_result := false;
    END IF;

    UPDATE public.championships
    SET
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::UUID[]), p_team_id),
        paid_teams   = CASE
            WHEN v_is_paid_result
            THEN array_append(COALESCE(paid_teams, ARRAY[]::UUID[]), p_team_id)
            ELSE COALESCE(paid_teams, ARRAY[]::UUID[])
        END,
        updated_at = v_now
    WHERE id = p_championship_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تسجيل الفريق في البطولة بنجاح.',
        'is_paid', v_is_paid_result,
        'joined_teams_count', v_joined_count + 1
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC) TO authenticated, service_role;

COMMIT;