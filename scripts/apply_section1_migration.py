import json
from scripts.db_client import run_sql

migration_sql = """
-- 1. Alter is_approved default to false
ALTER TABLE public.championships ALTER COLUMN is_approved SET DEFAULT false;

-- 2. Update sensitive fields trigger for INSERT and UPDATE
CREATE OR REPLACE FUNCTION public.protect_championship_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
BEGIN
  IF (current_user = 'postgres' OR current_user = 'service_role') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.is_approved = true THEN
      RAISE EXCEPTION 'Security Alert: Non-admin users cannot create pre-approved championships.';
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.is_approved IS DISTINCT FROM OLD.is_approved AND NEW.is_approved = true THEN
      RAISE EXCEPTION 'Security Alert: Championship approval requires admin verification.';
    END IF;

    IF NEW.champion_team_id IS DISTINCT FROM OLD.champion_team_id AND NEW.champion_team_id IS NOT NULL THEN
      RAISE EXCEPTION 'Security Alert: Crowning tournament champion must be performed via tournament engine.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_championship_sensitive_fields ON public.championships;
CREATE TRIGGER trg_protect_championship_sensitive_fields
BEFORE INSERT OR UPDATE ON public.championships
FOR EACH ROW
EXECUTE FUNCTION public.protect_championship_sensitive_fields();

-- 3. Harden RLS championships_insert policy
DROP POLICY IF EXISTS "championships_insert" ON public.championships;
CREATE POLICY "championships_insert" ON public.championships
FOR INSERT TO authenticated
WITH CHECK (
    (select auth.uid()) = owner_id
    AND EXISTS (
        SELECT 1 FROM public.users
        WHERE id = (select auth.uid())
          AND role IN ('owner', 'admin', 'co_founder', 'super_admin', 'cofounder')
    )
    AND (
        (is_approved IS NOT TRUE)
        OR EXISTS (
            SELECT 1 FROM public.users
            WHERE id = (select auth.uid())
              AND role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
        )
    )
);

-- 4. Atomic Admin Approval RPC
CREATE OR REPLACE FUNCTION public.admin_approve_championship_atomic(p_championship_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_champ RECORD;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
  IF v_caller_role NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
    RAISE EXCEPTION 'Permission Denied: Only administrators can approve championships';
  END IF;

  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found with ID: %', p_championship_id;
  END IF;

  IF v_champ.is_approved = true THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_approved', true,
      'message', 'Championship was already approved.'
    );
  END IF;

  UPDATE public.championships
  SET is_approved = true,
      updated_at = NOW()
  WHERE id = p_championship_id;

  IF v_champ.owner_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id,
      title,
      body,
      message,
      type,
      metadata,
      created_at
    ) VALUES (
      v_champ.owner_id,
      'تمت الموافقة على بطولتك',
      'تم اعتماد ونشر بطولتك "' || COALESCE(v_champ.name, '') || '" بنجاح وأصبحت متاحة لجميع الفرق للتسجيل.',
      'تم اعتماد ونشر بطولتك "' || COALESCE(v_champ.name, '') || '" بنجاح وأصبحت متاحة لجميع الفرق للتسجيل.',
      'tournament_approval',
      jsonb_build_object('championship_id', p_championship_id, 'status', 'approved'),
      NOW()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', p_championship_id,
    'is_approved', true,
    'message', 'Championship approved successfully.'
  );
END;
$$;

-- 5. Atomic Admin Rejection RPC
CREATE OR REPLACE FUNCTION public.admin_reject_championship_atomic(
  p_championship_id UUID,
  p_reason TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_champ RECORD;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Caller not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
  IF v_caller_role NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
    RAISE EXCEPTION 'Permission Denied: Only administrators can reject championships';
  END IF;

  SELECT * INTO v_champ
  FROM public.championships
  WHERE id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found with ID: %', p_championship_id;
  END IF;

  DELETE FROM public.championships
  WHERE id = p_championship_id;

  IF v_champ.owner_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id,
      title,
      body,
      message,
      type,
      metadata,
      created_at
    ) VALUES (
      v_champ.owner_id,
      'تم رفض نشر البطولة',
      'نأسف، تم رفض نشر بطولتك "' || COALESCE(v_champ.name, '') || '"' ||
      CASE WHEN p_reason IS NOT NULL AND TRIM(p_reason) != ''
           THEN '. السبب: ' || p_reason
           ELSE '.' END,
      'تم رفض نشر بطولتك "' || COALESCE(v_champ.name, '') || '"' ||
      CASE WHEN p_reason IS NOT NULL AND TRIM(p_reason) != ''
           THEN '. السبب: ' || p_reason
           ELSE '.' END,
      'tournament_rejection',
      jsonb_build_object('championship_name', v_champ.name, 'reason', p_reason),
      NOW()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', p_championship_id,
    'message', 'Championship rejected and removed successfully.'
  );
END;
$$;

-- 6. Permissions
GRANT EXECUTE ON FUNCTION public.admin_approve_championship_atomic(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_championship_atomic(UUID, TEXT) TO authenticated;
"""

if __name__ == "__main__":
    print("Applying Section 1 Migration...")
    res = run_sql(migration_sql)
    print("Migration applied successfully!")
    print(json.dumps(res, indent=2))
