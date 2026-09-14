-- ============================================================================
-- VSP MIGRATION: 20260916000001_stage8_1_containment.sql
-- Description: Stage 8.1 Containment - Eliminate Ghost Referral Notifications,
--              Decouple QR Verification, and Purge Test Artifacts.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. UPDATE process_referral_reward_on_qr_verification TO SILENCE NOTIFICATIONS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.process_referral_reward_on_qr_verification(
    p_booking_id uuid,
    p_invitee_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_ref RECORD;
    v_first_qr_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF p_invitee_id IS NULL THEN
        RETURN false;
    END IF;

    -- 1. Check if user has an active, legitimate pending referral
    SELECT * INTO v_ref
    FROM public.referrals
    WHERE invitee_user_id = p_invitee_id
      AND status = 'pending'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- 2. Verify this is the invitee's first completed QR-verified booking
    SELECT COUNT(*) INTO v_first_qr_count
    FROM public.bookings
    WHERE (user_id = p_invitee_id OR created_by_user_id = p_invitee_id)
      AND status = 'completed'
      AND qr_scanned_at IS NOT NULL;

    -- Only release reward on the very first QR verified booking
    IF v_first_qr_count <> 1 THEN
        RETURN false;
    END IF;

    -- 3. Mark referral rewarded atomically
    UPDATE public.referrals
    SET 
        status = 'rewarded',
        qualified_at = v_now,
        qualifying_booking_id = p_booking_id
    WHERE id = v_ref.id;

    -- 4. Record Inviter Points (+250) in internal ledger
    PERFORM set_config('vsp.system_override', 'true', true);
    UPDATE public.users
    SET points = COALESCE(points, 0) + 250,
        updated_at = v_now
    WHERE id = v_ref.inviter_user_id;

    INSERT INTO public.points_ledger (
        user_id,
        points_delta,
        balance_after,
        reason,
        reference_id,
        created_at
    )
    SELECT 
        v_ref.inviter_user_id,
        250,
        points,
        'referral_inviter_reward',
        p_booking_id::text,
        v_now
    FROM public.users WHERE id = v_ref.inviter_user_id;

    -- 5. Record Invitee Points (+500) in internal ledger
    UPDATE public.users
    SET points = COALESCE(points, 0) + 500,
        updated_at = v_now
    WHERE id = v_ref.invitee_user_id;

    INSERT INTO public.points_ledger (
        user_id,
        points_delta,
        balance_after,
        reason,
        reference_id,
        created_at
    )
    SELECT 
        v_ref.invitee_user_id,
        500,
        points,
        'referral_invitee_reward',
        p_booking_id::text,
        v_now
    FROM public.users WHERE id = v_ref.invitee_user_id;

    -- CRITICAL STAGE 8.1 CONTAINMENT:
    -- Absolutely NO user-facing push notifications claiming cash/wallet deposits are sent.
    -- Points remain silent internal loyalty tracking until an official product flow is authorized.

    RETURN true;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.process_referral_reward_on_qr_verification(uuid, uuid) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. PURGE TEST POLLUTION FROM PREVIOUS ATTACK TEST RUNS
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    -- Delete synthetic notifications referencing referral_reward
    DELETE FROM public.notifications 
    WHERE type = 'referral_reward';

    -- Delete synthetic test referrals
    DELETE FROM public.referrals 
    WHERE referral_code = 'OWNERREF';

    -- Delete synthetic points ledger entries from test runs
    DELETE FROM public.points_ledger 
    WHERE reason IN ('referral_inviter_reward', 'referral_invitee_reward');

    -- Reset points on test development accounts
    PERFORM set_config('vsp.system_override', 'true', true);
    UPDATE public.users
    SET points = 0
    WHERE id IN (
        '46967c5c-f8cd-4a22-a4b6-44556c44360b',
        '70830a34-5488-4377-9261-6fa814fdf6cd'
    );
END $$;
