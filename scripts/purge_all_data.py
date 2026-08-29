import urllib.request
import urllib.error
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = """
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    -- 1. Disable triggers temporarily for fast and clean cascade truncation
    SET session_replication_role = 'replica';

    -- 2. Delete all records from public tables
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'TRUNCATE TABLE public.' || quote_ident(r.tablename) || ' CASCADE;';
    END LOOP;

    -- 3. Delete all records from auth.users
    DELETE FROM auth.users;

    -- 4. Delete storage objects
    DELETE FROM storage.objects;

    -- 5. Re-enable triggers
    SET session_replication_role = 'origin';
END $$;
"""

payload = json.dumps({"query": sql}).encode("utf-8")
req = urllib.request.Request(
    url,
    data=payload,
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
        "User-Agent": "Mozilla/5.0",
    },
    method="POST",
)

try:
    with urllib.request.urlopen(req) as resp:
        print("✅ DATABASE PURGE COMPLETED SUCCESSFULLY!")
        print(resp.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print("❌ ERROR:", e.read().decode('utf-8'))
