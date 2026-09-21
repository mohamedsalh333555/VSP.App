-- ==============================================================================
-- VSP DATABASE MIGRATION: 20260920000001_remediate_audit_findings_atomic_rpcs_and_tables.sql
-- Remediates audit findings:
-- 1. Creates missing `owner_documents` table with RLS.
-- 2. Implements `save_and_publish_1v1_tournament_atomic` RPC to eliminate race conditions.
-- 3. Implements `admin_set_owner_subscription_atomic` RPC for safe admin plan updates.
-- 4. Creates `pgmq_read` and `pgmq_archive` public wrapper RPCs for fcm_queue_worker.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CREATE TABLE: owner_documents
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.owner_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL DEFAULT 'commercial_registry',
  file_url TEXT NOT NULL,
  storage_path TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.owner_documents ENABLE ROW LEVEL SECURITY;

-- Indexes for performant lookup
CREATE INDEX IF NOT EXISTS idx_owner_documents_owner_id ON public.owner_documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_owner_documents_status ON public.owner_documents(status);

-- Policies
DROP POLICY IF EXISTS "owner_documents_owner_select" ON public.owner_documents;
CREATE POLICY "owner_documents_owner_select"
  ON public.owner_documents
  FOR SELECT
  TO authenticated
  USING (
    owner_id = auth.uid() 
    OR (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'cofounder')
  );

DROP POLICY IF EXISTS "owner_documents_owner_insert" ON public.owner_documents;
CREATE POLICY "owner_documents_owner_insert"
  ON public.owner_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    owner_id = auth.uid() 
    OR (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'cofounder')
  );

DROP POLICY IF EXISTS "owner_documents_admin_update" ON public.owner_documents;
CREATE POLICY "owner_documents_admin_update"
  ON public.owner_documents
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'cofounder')
  )
  WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'cofounder')
  );

DROP POLICY IF EXISTS "owner_documents_admin_delete" ON public.owner_documents;
CREATE POLICY "owner_documents_admin_delete"
  ON public.owner_documents
  FOR DELETE
  TO authenticated
  USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'cofounder')
  );

-- Service role bypass policy
DROP POLICY IF EXISTS "owner_documents_service_role" ON public.owner_documents;
CREATE POLICY "owner_documents_service_role"
  ON public.owner_documents
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- ------------------------------------------------------------------------------
-- 2. RPC: save_and_publish_1v1_tournament_atomic
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_and_publish_1v1_tournament_atomic(
  p_tournament_id UUID,
  p_players JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_inserted_count INT := 0;
BEGIN
  -- 1. Verify caller authorization
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'cofounder') AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can save and publish tournaments';
  END IF;

  -- 2. Ensure tournament exists and lock row
  IF NOT EXISTS (SELECT 1 FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id FOR UPDATE) THEN
    RAISE EXCEPTION 'Tournament not found with ID: %', p_tournament_id;
  END IF;

  -- 3. Clear existing player scores for this tournament
  DELETE FROM public.vsp_1v1_tournament_players
  WHERE tournament_id = p_tournament_id;

  -- 4. Insert new player scores atomically
  IF p_players IS NOT NULL AND jsonb_array_length(p_players) > 0 THEN
    INSERT INTO public.vsp_1v1_tournament_players (
      tournament_id,
      player_name,
      user_id,
      avatar_url,
      tackles,
      goals,
      skills
    )
    SELECT
      p_tournament_id,
      COALESCE(NULLIF(TRIM(elem->>'player_name'), ''), NULLIF(TRIM(elem->>'name'), ''), 'لاعب'),
      CASE 
        WHEN elem->>'user_id' IS NOT NULL AND TRIM(elem->>'user_id') <> '' 
        THEN (elem->>'user_id')::UUID 
        ELSE NULL 
      END,
      NULLIF(TRIM(elem->>'avatar_url'), ''),
      GREATEST(0, COALESCE((elem->>'tackles')::INT, 0)),
      GREATEST(0, COALESCE((elem->>'goals')::INT, 0)),
      GREATEST(0, COALESCE((elem->>'skills')::INT, (elem->>'skill_points')::INT, 0))
    FROM jsonb_array_elements(p_players) AS elem;

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
  END IF;

  -- 5. Update tournament status to published
  UPDATE public.vsp_1v1_tournaments
  SET 
    status = 'published',
    updated_at = NOW()
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true,
    'tournament_id', p_tournament_id,
    'players_count', v_inserted_count,
    'status', 'published'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_and_publish_1v1_tournament_atomic(UUID, JSONB) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 3. RPC: admin_set_owner_subscription_atomic
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_owner_subscription_atomic(
  p_owner_id UUID,
  p_plan TEXT,
  p_days INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_current_plan TEXT;
  v_current_expires_at TIMESTAMPTZ;
  v_base_time TIMESTAMPTZ := NOW();
  v_new_expires_at TIMESTAMPTZ := NULL;
BEGIN
  -- 1. Authorization check
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'cofounder') AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can alter owner subscriptions';
  END IF;

  -- 2. Lock target user
  SELECT subscription_plan, subscription_expires_at
  INTO v_current_plan, v_current_expires_at
  FROM public.users
  WHERE id = p_owner_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owner not found with ID: %', p_owner_id;
  END IF;

  -- 3. Calculate new expiry
  IF LOWER(TRIM(p_plan)) = 'pro' THEN
    -- If already pro with active expiry date in the future, extend cumulatively
    IF v_current_plan = 'pro' AND v_current_expires_at IS NOT NULL AND v_current_expires_at > NOW() THEN
      v_base_time := v_current_expires_at;
    END IF;

    v_new_expires_at := v_base_time + (COALESCE(p_days, 30) || ' days')::INTERVAL;

    UPDATE public.users
    SET 
      subscription_plan = 'pro',
      subscription_expires_at = v_new_expires_at,
      updated_at = NOW()
    WHERE id = p_owner_id;
  ELSE
    -- Downgrade to basic/free_trial
    UPDATE public.users
    SET 
      subscription_plan = 'free_trial',
      subscription_expires_at = NULL,
      updated_at = NOW()
    WHERE id = p_owner_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'owner_id', p_owner_id,
    'subscription_plan', CASE WHEN LOWER(TRIM(p_plan)) = 'pro' THEN 'pro' ELSE 'free_trial' END,
    'subscription_expires_at', v_new_expires_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_owner_subscription_atomic(UUID, TEXT, INT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 4. PGMQ RPC WRAPPERS: pgmq_read & pgmq_archive
-- Note: User should ensure pgmq extension is enabled in Supabase Dashboard.
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pgmq;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pgmq extension could not be created via SQL (can be toggled in Supabase Dashboard): %', SQLERRM;
END $$;

-- Wrapper for reading messages
CREATE OR REPLACE FUNCTION public.pgmq_read(
  queue_name text,
  vt integer DEFAULT 30,
  qty integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb := '[]'::jsonb;
BEGIN
  -- Security check: service_role or admin only
  IF auth.role() <> 'service_role' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'Access denied: service_role or admin required';
    END IF;
  END IF;

  -- If pgmq extension schema exists, delegate to pgmq.read
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'pgmq') THEN
    BEGIN
      EXECUTE format(
        'SELECT COALESCE(jsonb_agg(to_jsonb(r)), ''[]''::jsonb) FROM pgmq.read(%L, %s, %s) r',
        queue_name, vt, qty
      ) INTO v_result;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'pgmq.read execution notice: %', SQLERRM;
      v_result := '[]'::jsonb;
    END;
  END IF;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- Wrapper for archiving messages
CREATE OR REPLACE FUNCTION public.pgmq_archive(
  queue_name text,
  msg_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_archived boolean := true;
BEGIN
  -- Security check: service_role or admin only
  IF auth.role() <> 'service_role' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'Access denied: service_role or admin required';
    END IF;
  END IF;

  -- If pgmq extension schema exists, delegate to pgmq.archive
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'pgmq') THEN
    BEGIN
      EXECUTE format('SELECT pgmq.archive(%L, %s)', queue_name, msg_id) INTO v_archived;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'pgmq.archive execution notice: %', SQLERRM;
      v_archived := false;
    END;
  END IF;

  RETURN COALESCE(v_archived, true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.pgmq_read(text, integer, integer) TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION public.pgmq_archive(text, bigint) TO service_role, authenticated;
