"""
VSP Supabase Migration Script
Applies the handle_new_user trigger fix via Supabase Management API.
Usage: python scripts/apply_supabase_migration.py --service-key YOUR_SERVICE_ROLE_KEY
"""
import urllib.request
import urllib.error
import json
import sys
import argparse

SUPABASE_URL = "https://mktqkddbcddrxjxabdua.supabase.co"
PROJECT_REF  = "mktqkddbcddrxjxabdua"

SQL_MIGRATION = """
-- =============================================
-- VSP Migration: Fix Google OAuth + add date_of_birth
-- =============================================

-- 1. Add date_of_birth column (safe, idempotent)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS date_of_birth TEXT;

-- 2. Create/replace the handle_new_user trigger function (bulletproof version)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (
    id, 
    email, 
    name, 
    role, 
    is_registration_complete, 
    is_email_verified
  )
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    COALESCE(
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'full_name',
      'Player'
    ),
    COALESCE(new.raw_user_meta_data->>'role', 'player'),
    false,
    new.email_confirmed_at IS NOT NULL
  )
  ON CONFLICT (id) DO UPDATE 
  SET 
    email = EXCLUDED.email,
    name  = EXCLUDED.name;
      
  RETURN new;
END;
$$;

-- 3. Re-attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
"""

def run_sql(service_key: str, sql: str) -> dict:
    """Execute SQL via Supabase Management API."""
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
    payload = json.dumps({"query": sql}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {service_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return {"status": resp.status, "body": json.loads(resp.read())}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return {"status": e.code, "error": body}
    except Exception as e:
        return {"status": -1, "error": str(e)}


def main():
    parser = argparse.ArgumentParser(description="Apply VSP Supabase migration")
    parser.add_argument("--service-key", required=True, help="Supabase service_role key")
    args = parser.parse_args()

    print("🚀 Applying VSP Supabase migration...")
    print(f"   Project: {PROJECT_REF}")
    print()

    result = run_sql(args.service_key, SQL_MIGRATION)
    status = result.get("status", -1)

    if status in (200, 201):
        print("✅ Migration applied successfully!")
        print(json.dumps(result.get("body", {}), indent=2))
    else:
        print(f"❌ Migration failed (HTTP {status}):")
        print(result.get("error", result))
        sys.exit(1)


if __name__ == "__main__":
    main()
