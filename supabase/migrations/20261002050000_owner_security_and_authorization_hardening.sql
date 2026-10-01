-- Migration: 20261002050000_owner_security_and_authorization_hardening.sql
-- Goal: Fix Authorization in SECURITY DEFINER RPCs and harden user sensitive fields trigger:
--   1. Replace current_user checks with strict auth.jwt() and auth.uid() checks.
--   2. Enforce strict 4 verification documents (no contractUrl, no generic nationalIdUrl).
--   3. Fix trg_fn_protect_user_sensitive_fields so authenticated users cannot bypass protection.

-- =============================================================================
-- 1. HARDEN trg_fn_protect_user_sensitive_fields
-- =============================================================================

CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_system_override boolean := (current_setting('vsp.system_override', true) = 'true');
    v_jwt_role           text := COALESCE(auth.jwt() ->> 'role', auth.role(), '');
    v_caller_id          uuid := auth.uid();
    v_is_admin           boolean := false;
BEGIN
    -- 1. Trusted internal system override
    IF v_is_system_override THEN
        RETURN NEW;
    END IF;

    -- 2. Service role execution
    IF v_jwt_role = 'service_role' THEN
        RETURN NEW;
    END IF;

    -- 3. Direct database session maintenance without any HTTP/JWT context
    IF v_caller_id IS NULL AND v_jwt_role = '' AND session_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    -- 4. Check if authenticated caller is admin / co-founder
    IF v_caller_id IS NOT NULL THEN
        SELECT (role IN ('admin', 'co_founder', 'cofounder', 'super_admin'))
        INTO v_is_admin
        FROM public.users
        WHERE id = v_caller_id;
    END IF;

    IF COALESCE(v_is_admin, false) THEN 
        RETURN NEW; 
    END IF;

    -- 5. Regular authenticated client trying to alter sensitive columns
    IF OLD.role IS DISTINCT FROM NEW.role
       OR OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan
       OR OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at
       OR OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at
       OR OLD.total_platform_fees IS DISTINCT FROM NEW.total_platform_fees
       OR OLD.cash_booking_banned IS DISTINCT FROM NEW.cash_booking_banned
       OR OLD.no_show_count IS DISTINCT FROM NEW.no_show_count
       OR OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified
       OR OLD.is_email_verified IS DISTINCT FROM NEW.is_email_verified
       OR OLD.verification_status IS DISTINCT FROM NEW.verification_status
       OR OLD.is_blocked IS DISTINCT FROM NEW.is_blocked
       OR OLD.has_stadium IS DISTINCT FROM NEW.has_stadium
       OR OLD.is_registration_complete IS DISTINCT FROM NEW.is_registration_complete
       OR OLD.is_onboarding_confirmed IS DISTINCT FROM NEW.is_onboarding_confirmed
       OR OLD.accumulated_cash_debt IS DISTINCT FROM NEW.accumulated_cash_debt
       OR OLD.debt_limit IS DISTINCT FROM NEW.debt_limit
       OR OLD.is_debt_blocked IS DISTINCT FROM NEW.is_debt_blocked
       OR OLD.points IS DISTINCT FROM NEW.points THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Account security, financial state, and lifecycle fields are server-authoritative.'
          USING errcode = '42501', detail = 'UNAUTHORIZED_USER_SENSITIVE_UPDATE';
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- 2. HARDEN update_owner_verification_document (STRICT AUTH.UID & ADMIN AUTHORIZATION)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.update_owner_verification_document(
  p_user_id uuid,
  p_doc_field_name text,
  p_file_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_existing        jsonb;
  v_data            jsonb;
BEGIN
  -- Strict Authorization: Service role, or user modifying own docs, or Admin
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF p_user_id IS DISTINCT FROM v_caller_id AND NOT public.is_admin_or_cofounder(v_caller_id) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  -- Strictly allowed document field names (removed generic nationalIdUrl)
  IF p_doc_field_name NOT IN (
    'nationalIdFrontUrl', 'nationalIdBackUrl',
    'commercialRegisterUrl', 'taxCardUrl', 'stadiumOwnershipProofUrl'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DOCUMENT_FIELD');
  END IF;

  IF nullif(trim(COALESCE(p_file_url, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DOCUMENT_URL');
  END IF;

  SELECT COALESCE(additional_data, '{}'::jsonb) INTO v_existing
  FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  v_data := jsonb_set(
    v_existing,
    '{verificationDocuments}',
    COALESCE(v_existing->'verificationDocuments', '{}'::jsonb) ||
      jsonb_build_object(p_doc_field_name, trim(p_file_url)),
    true
  );

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET additional_data = v_data,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN jsonb_build_object('success', true, 'doc_field_name', p_doc_field_name);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_owner_verification_document(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_owner_verification_document(uuid, text, text) TO authenticated, service_role;

-- =============================================================================
-- 3. HARDEN submit_owner_verification (STRICT AUTH.UID & 4 MANDATORY DOCUMENTS ONLY)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.submit_owner_verification(
  p_owner_id uuid DEFAULT NULL,
  p_additional_data jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_uid             uuid;
  v_has_stadium     boolean := false;
  v_existing_data   jsonb;
  v_merged_data     jsonb;
  v_docs            jsonb;
  v_cr              text;
  v_tc              text;
  v_idf             text;
  v_idb             text;
BEGIN
  -- Strict Authorization: Service role, or owner submitting own verification, or Admin
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF p_owner_id IS NOT NULL AND p_owner_id IS DISTINCT FROM v_caller_id THEN
      IF NOT public.is_admin_or_cofounder(v_caller_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
      END IF;
      v_uid := p_owner_id;
    ELSE
      v_uid := v_caller_id;
    END IF;
  ELSE
    v_uid := COALESCE(p_owner_id, v_caller_id);
  END IF;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Owner ID required');
  END IF;

  -- Check user existence and lock row
  SELECT additional_data INTO v_existing_data
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  -- Check authoritative existence of active stadium
  SELECT EXISTS (
    SELECT 1 FROM public.stadiums 
    WHERE owner_id = v_uid AND COALESCE(is_deleted_by_owner, false) = false
  ) INTO v_has_stadium;

  IF NOT v_has_stadium THEN
    RETURN jsonb_build_object('success', false, 'error', 'ACTIVE_STADIUM_REQUIRED');
  END IF;

  -- Merge existing user additional_data with incoming p_additional_data
  v_merged_data := COALESCE(v_existing_data, '{}'::jsonb) || COALESCE(p_additional_data, '{}'::jsonb);
  v_docs := COALESCE(v_merged_data->'verificationDocuments', '{}'::jsonb);

  -- 1. Commercial Register (STRICT: only commercialRegisterUrl or commercialRegister)
  v_cr := COALESCE(
    nullif(trim(v_docs->>'commercialRegisterUrl'), ''),
    nullif(trim(v_docs->>'commercialRegister'), ''),
    nullif(trim(v_merged_data->>'commercialRegisterUrl'), ''),
    nullif(trim(v_merged_data->>'commercialRegister'), '')
  );
  IF v_cr IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_COMMERCIAL_REGISTER');
  END IF;

  -- 2. Tax Card (STRICT: only taxCardUrl or taxCard)
  v_tc := COALESCE(
    nullif(trim(v_docs->>'taxCardUrl'), ''),
    nullif(trim(v_docs->>'taxCard'), ''),
    nullif(trim(v_merged_data->>'taxCardUrl'), ''),
    nullif(trim(v_merged_data->>'taxCard'), '')
  );
  IF v_tc IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_TAX_CARD');
  END IF;

  -- 3. National ID Front (STRICT: only nationalIdFrontUrl or idFront)
  v_idf := COALESCE(
    nullif(trim(v_docs->>'nationalIdFrontUrl'), ''),
    nullif(trim(v_docs->>'idFront'), ''),
    nullif(trim(v_merged_data->>'nationalIdFrontUrl'), ''),
    nullif(trim(v_merged_data->>'idFront'), '')
  );
  IF v_idf IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_NATIONAL_ID_FRONT');
  END IF;

  -- 4. National ID Back (STRICT: only nationalIdBackUrl or idBack)
  v_idb := COALESCE(
    nullif(trim(v_docs->>'nationalIdBackUrl'), ''),
    nullif(trim(v_docs->>'idBack'), ''),
    nullif(trim(v_merged_data->>'nationalIdBackUrl'), ''),
    nullif(trim(v_merged_data->>'idBack'), '')
  );
  IF v_idb IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_NATIONAL_ID_BACK');
  END IF;

  -- Normalize verificationDocuments inside v_merged_data
  v_merged_data := jsonb_set(
    v_merged_data,
    '{verificationDocuments}',
    v_docs || jsonb_build_object(
      'commercialRegisterUrl', v_cr,
      'taxCardUrl', v_tc,
      'nationalIdFrontUrl', v_idf,
      'nationalIdBackUrl', v_idb
    ),
    true
  );

  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET verification_status = 'pending',
      is_registration_complete = true,
      has_stadium = v_has_stadium,
      additional_data = v_merged_data,
      updated_at = now()
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'verification_status', 'pending',
    'has_stadium', v_has_stadium,
    'message', 'Owner verification submitted successfully'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_owner_verification(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_owner_verification(uuid, jsonb) TO authenticated, service_role;

-- =============================================================================
-- 4. HARDEN reject_payout_settlement_atomic (STRICT AUTH.UID & ADMIN ROLE CHECK)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.reject_payout_settlement_atomic(
  p_settlement_id uuid,
  p_rejection_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_settlement      record;
  v_now             timestamptz := timezone('utc', now());
  v_reason          text := trim(COALESCE(p_rejection_reason, ''));
BEGIN
  -- Strict Admin Authorization Check
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF NOT public.is_admin_or_cofounder(v_caller_id) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_ADMIN_REQUIRED');
    END IF;
  END IF;

  -- Lock settlement FOR UPDATE
  SELECT * INTO v_settlement
  FROM public.payout_settlements
  WHERE id = p_settlement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'SETTLEMENT_NOT_FOUND');
  END IF;

  -- Idempotency: If already rejected, return idempotent success
  IF v_settlement.status = 'rejected' THEN
    RETURN jsonb_build_object(
      'success', true,
      'idempotent', true,
      'settlement_id', p_settlement_id,
      'status', 'rejected',
      'amount', v_settlement.amount,
      'message', 'Settlement is already rejected'
    );
  END IF;

  -- Cannot reject if already completed / paid out
  IF v_settlement.status = 'completed' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CANNOT_REJECT_COMPLETED',
      'message', 'لا يمكن رفض طلب تسوية تم صرفه واكتماله بالفعل'
    );
  END IF;

  -- Only pending or approved can be rejected
  IF v_settlement.status NOT IN ('pending', 'approved') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_SETTLEMENT_STATE',
      'message', 'حالة طلب التسوية لا تسمح بالرفض'
    );
  END IF;

  -- Update settlement status to 'rejected'
  UPDATE public.payout_settlements
  SET status = 'rejected',
      admin_notes = CASE 
        WHEN v_reason <> '' THEN v_reason 
        ELSE admin_notes 
      END,
      updated_at = v_now
  WHERE id = p_settlement_id;

  -- Update linked transactions in transactions table
  UPDATE public.transactions
  SET type = 'payout_rejected',
      status = 'failed',
      description = 'رفض طلب سحب أرباح المالك من قبل الإدارة',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'rejected_by', v_caller_id,
        'rejected_at', v_now,
        'rejection_reason', v_reason
      ),
      updated_at = v_now
  WHERE (metadata->>'settlement_id') = p_settlement_id::text
    AND type IN ('payout_pending', 'payout');

  -- Insert notification for owner
  INSERT INTO public.notifications(
    user_id,
    title,
    body,
    type,
    is_read,
    created_at
  ) VALUES (
    v_settlement.owner_id,
    'تم رفض طلب سحب الأرباح ⚠️',
    'تم رفض طلب تسوية الأرباح بمبلغ ' || round(v_settlement.amount, 2) || ' ج.م.' || 
      CASE WHEN v_reason <> '' THEN ' السبب: ' || v_reason ELSE '' END,
    'payout',
    false,
    v_now
  );

  RETURN jsonb_build_object(
    'success', true,
    'idempotent', false,
    'settlement_id', p_settlement_id,
    'status', 'rejected',
    'restored_amount', round(v_settlement.amount, 2),
    'message', 'تم رفض طلب التسوية واستعادة الرصيد للمالك بنجاح.'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reject_payout_settlement_atomic(uuid, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.reject_payout_settlement_atomic(uuid, text) TO authenticated, service_role;

-- =============================================================================
-- 5. HARDEN approve_payout_settlement_atomic (STRICT AUTH.UID & ADMIN ROLE CHECK)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.approve_payout_settlement_atomic(
  p_settlement_id uuid,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE 
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_settlement      record; 
  v_now             timestamptz := timezone('utc', now()); 
  v_tx_id           uuid;
BEGIN
  -- Strict Admin Authorization Check
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF NOT public.is_admin_or_cofounder(v_caller_id) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_ADMIN_REQUIRED');
    END IF;
  END IF;

  SELECT * INTO v_settlement FROM public.payout_settlements WHERE id = p_settlement_id FOR UPDATE;
  IF NOT FOUND THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Settlement record not found'); 
  END IF;

  IF v_settlement.status = 'completed' THEN 
    RETURN jsonb_build_object('success', true, 'idempotent', true, 'settlement_id', p_settlement_id, 'amount', v_settlement.amount); 
  END IF;

  IF v_settlement.status NOT IN ('pending', 'approved') THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Settlement is not payable in its current state'); 
  END IF;

  UPDATE public.payout_settlements 
  SET status = 'completed', 
      admin_notes = COALESCE(p_admin_notes, admin_notes), 
      updated_at = v_now 
  WHERE id = p_settlement_id;

  SELECT id INTO v_tx_id FROM public.transactions 
  WHERE type = 'payout_pending' AND status = 'pending' AND (metadata->>'settlement_id') = p_settlement_id::text 
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF v_tx_id IS NOT NULL THEN
    UPDATE public.transactions 
    SET type = 'payout_disbursed', 
        status = 'completed', 
        description = 'صرف أرباح مالك ملعب بعد اعتماد الإدارة',
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('approved_by', v_caller_id, 'approved_at', v_now, 'admin_notes', p_admin_notes), 
        updated_at = v_now 
    WHERE id = v_tx_id;
  ELSE
    SELECT id INTO v_tx_id FROM public.transactions 
    WHERE type = 'payout_disbursed' AND status = 'completed' AND (metadata->>'settlement_id') = p_settlement_id::text 
    LIMIT 1;

    IF v_tx_id IS NULL THEN
      INSERT INTO public.transactions(user_id, amount, type, status, payment_method, reference_number, metadata, created_at, updated_at)
      VALUES(v_settlement.owner_id, v_settlement.amount, 'payout_disbursed', 'completed', v_settlement.method, 'SETTLEMENT_' || replace(p_settlement_id::text, '-', ''),
        jsonb_build_object('settlement_id', p_settlement_id, 'destination', v_settlement.destination, 'approved_by', v_caller_id, 'approved_at', v_now, 'admin_notes', p_admin_notes), v_now, v_now) 
      RETURNING id INTO v_tx_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'settlement_id', p_settlement_id, 'transaction_id', v_tx_id, 'amount', v_settlement.amount);
END;$function$;

REVOKE EXECUTE ON FUNCTION public.approve_payout_settlement_atomic(uuid, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.approve_payout_settlement_atomic(uuid, text) TO authenticated, service_role;

-- =============================================================================
-- 6. RECONCILE SCHEMA MIGRATIONS
-- =============================================================================

INSERT INTO supabase_migrations.schema_migrations (version)
VALUES ('20261002050000')
ON CONFLICT (version) DO NOTHING;
