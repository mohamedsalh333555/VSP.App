-- Migration: 20261002040000_owner_verification_and_payout_closure.sql
-- Goal: Close Owner Journeys:
--   1. Stadium Onboarding & Verification (server-authoritative document enforcement & active stadium check)
--   2. Payout & Settlement (reject_payout_settlement_atomic, balance restoration SSOT, prevent direct client mutation)

-- =============================================================================
-- 1. PAYOUT SETTLEMENTS METHOD CONSTRAINT & ACCESS HARDENING
-- =============================================================================

ALTER TABLE public.payout_settlements DROP CONSTRAINT IF EXISTS payout_settlements_method_check;
ALTER TABLE public.payout_settlements ADD CONSTRAINT payout_settlements_method_check 
  CHECK (method = ANY (ARRAY['instapay'::text, 'wallet'::text, 'vodafone_cash'::text, 'bank'::text, 'bank_transfer'::text, 'unknown'::text]));

-- Prevent direct client UPDATE / INSERT / DELETE on payout_settlements; RPCs are the SSOT
DROP POLICY IF EXISTS "payout_settlements_admin_manage" ON public.payout_settlements;

REVOKE INSERT, UPDATE, DELETE ON public.payout_settlements FROM anon, authenticated, public;
GRANT SELECT ON public.payout_settlements TO authenticated;
GRANT ALL ON public.payout_settlements TO service_role, postgres;

-- =============================================================================
-- 2. HARDEN update_owner_verification_document
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
  v_existing jsonb;
  v_data jsonb;
BEGIN
  IF auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
  END IF;

  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  IF p_doc_field_name NOT IN (
    'nationalIdUrl','nationalIdFrontUrl','nationalIdBackUrl',
    'commercialRegisterUrl','taxCardUrl','stadiumOwnershipProofUrl'
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
-- 3. HARDEN submit_owner_verification (SERVER-AUTHORITATIVE DOCUMENT & STADIUM VALIDATION)
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
  v_uid            uuid := COALESCE(p_owner_id, auth.uid());
  v_has_stadium    boolean := false;
  v_existing_data  jsonb;
  v_merged_data    jsonb;
  v_docs           jsonb;
  v_cr             text;
  v_tc             text;
  v_idf            text;
  v_idb            text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Owner ID required');
  END IF;

  -- Modern secure server-side authorization check
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
    IF v_uid IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
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

  -- 1. Commercial Register
  v_cr := COALESCE(
    nullif(trim(v_docs->>'commercialRegisterUrl'), ''),
    nullif(trim(v_docs->>'commercialRegister'), ''),
    nullif(trim(v_merged_data->>'commercialRegisterUrl'), ''),
    nullif(trim(v_merged_data->>'commercialRegister'), ''),
    nullif(trim(v_merged_data->>'contractUrl'), '')
  );
  IF v_cr IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_COMMERCIAL_REGISTER');
  END IF;

  -- 2. Tax Card
  v_tc := COALESCE(
    nullif(trim(v_docs->>'taxCardUrl'), ''),
    nullif(trim(v_docs->>'taxCard'), ''),
    nullif(trim(v_merged_data->>'taxCardUrl'), ''),
    nullif(trim(v_merged_data->>'taxCard'), '')
  );
  IF v_tc IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_TAX_CARD');
  END IF;

  -- 3. National ID Front
  v_idf := COALESCE(
    nullif(trim(v_docs->>'nationalIdFrontUrl'), ''),
    nullif(trim(v_docs->>'idFront'), ''),
    nullif(trim(v_docs->>'idFrontUrl'), ''),
    nullif(trim(v_docs->>'nationalIdUrl'), ''),
    nullif(trim(v_merged_data->>'nationalIdFrontUrl'), ''),
    nullif(trim(v_merged_data->>'idFront'), ''),
    nullif(trim(v_merged_data->>'nationalIdUrl'), ''),
    nullif(trim(v_merged_data->>'ownerIdUrl'), '')
  );
  IF v_idf IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'MISSING_NATIONAL_ID_FRONT');
  END IF;

  -- 4. National ID Back
  v_idb := COALESCE(
    nullif(trim(v_docs->>'nationalIdBackUrl'), ''),
    nullif(trim(v_docs->>'idBack'), ''),
    nullif(trim(v_docs->>'idBackUrl'), ''),
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
-- 4. CREATE reject_payout_settlement_atomic RPC
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
  v_caller_role  text;
  v_settlement   record;
  v_now          timestamptz := timezone('utc', now());
  v_reason       text := trim(COALESCE(p_rejection_reason, ''));
BEGIN
  -- 1. Authorization: Admin / co-founder / super_admin / service_role only
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
    IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_ADMIN_REQUIRED');
    END IF;
  END IF;

  -- 2. Lock settlement FOR UPDATE
  SELECT * INTO v_settlement
  FROM public.payout_settlements
  WHERE id = p_settlement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'SETTLEMENT_NOT_FOUND');
  END IF;

  -- 3. Idempotency: If already rejected, return idempotent success
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

  -- 4. Cannot reject if already completed / paid out
  IF v_settlement.status = 'completed' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CANNOT_REJECT_COMPLETED',
      'message', 'لا يمكن رفض طلب تسوية تم صرفه واكتماله بالفعل'
    );
  END IF;

  -- 5. Only pending or approved can be rejected
  IF v_settlement.status NOT IN ('pending', 'approved') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_SETTLEMENT_STATE',
      'message', 'حالة طلب التسوية لا تسمح بالرفض'
    );
  END IF;

  -- 6. Update settlement status to 'rejected'
  UPDATE public.payout_settlements
  SET status = 'rejected',
      admin_notes = CASE 
        WHEN v_reason <> '' THEN v_reason 
        ELSE admin_notes 
      END,
      updated_at = v_now
  WHERE id = p_settlement_id;

  -- 7. Update linked transactions in transactions table
  UPDATE public.transactions
  SET type = 'payout_rejected',
      status = 'failed',
      description = 'رفض طلب سحب أرباح المالك من قبل الإدارة',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'rejected_by', auth.uid(),
        'rejected_at', v_now,
        'rejection_reason', v_reason
      ),
      updated_at = v_now
  WHERE (metadata->>'settlement_id') = p_settlement_id::text
    AND type IN ('payout_pending', 'payout');

  -- 8. Insert notification for owner
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

  -- 9. Note on balance: Because get_owner_financial_summary computes pending_payouts as:
  --    SELECT COALESCE(SUM(amount),0) FROM public.payout_settlements WHERE owner_id=p_owner_id AND status IN ('pending','approved');
  --    Setting status='rejected' automatically excludes this settlement from pending_payouts,
  --    thereby restoring the available_balance cleanly and authoritatively without touching or mutating any balance column!

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
-- 5. MODERNIZE approve_payout_settlement_atomic (SECURE POSTGRES/SERVICE_ROLE & ADMIN CHECK)
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
  v_settlement record; 
  v_admin_role text; 
  v_now timestamptz := timezone('utc', now()); 
  v_tx_id uuid;
BEGIN
  -- Modern secure server-side authorization check
  IF current_user NOT IN ('postgres', 'service_role') AND COALESCE(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
    SELECT role INTO v_admin_role FROM public.users WHERE id = auth.uid();
    IF COALESCE(v_admin_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN 
      RETURN jsonb_build_object('success', false, 'error', 'Admin authorization required'); 
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
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('approved_by', auth.uid(), 'approved_at', v_now, 'admin_notes', p_admin_notes), 
        updated_at = v_now 
    WHERE id = v_tx_id;
  ELSE
    SELECT id INTO v_tx_id FROM public.transactions 
    WHERE type = 'payout_disbursed' AND status = 'completed' AND (metadata->>'settlement_id') = p_settlement_id::text 
    LIMIT 1;

    IF v_tx_id IS NULL THEN
      INSERT INTO public.transactions(user_id, amount, type, status, payment_method, reference_number, metadata, created_at, updated_at)
      VALUES(v_settlement.owner_id, v_settlement.amount, 'payout_disbursed', 'completed', v_settlement.method, 'SETTLEMENT_' || replace(p_settlement_id::text, '-', ''),
        jsonb_build_object('settlement_id', p_settlement_id, 'destination', v_settlement.destination, 'approved_by', auth.uid(), 'approved_at', v_now, 'admin_notes', p_admin_notes), v_now, v_now) 
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
VALUES ('20261002040000')
ON CONFLICT (version) DO NOTHING;
