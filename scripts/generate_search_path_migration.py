import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)
token = env["SUPABASE_MANAGEMENT_KEY"]
ref = "mktqkddbcddrxjxabdua"
url = f"https://api.supabase.com/v1/projects/{ref}/database/query"

sql = """
    SELECT 
        p.proname,
        p.oid,
        pg_get_function_identity_arguments(p.oid) as args,
        p.proconfig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND (p.proconfig IS NULL OR NOT array_to_string(p.proconfig, ',') ~* 'search_path=')
    ORDER BY p.proname;
"""

req = urllib.request.Request(url, data=json.dumps({'query': sql}).encode('utf-8'), headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {token}', 'User-Agent': 'Mozilla/5.0'}, method='POST')
with urllib.request.urlopen(req) as resp:
    funcs = json.loads(resp.read().decode('utf-8'))

print(f"Total security definer functions needing search_path: {len(funcs)}")

stmts = []
stmts.append("-- Migration: 202609050005_phase4_fix_function_search_paths.sql")
stmts.append("-- Description: Set search_path = public, pg_temp on all security definer functions to prevent search_path hijacking.\n")

for f in funcs:
    name = f['proname']
    args = f['args']
    full_ident = f"public.\"{name}\"({args})"
    stmts.append(f"ALTER FUNCTION {full_ident} SET search_path = public, pg_temp;")

content = "\n".join(stmts)
with open("supabase/migrations/202609050005_phase4_fix_function_search_paths.sql", "w", encoding="utf-8") as out:
    out.write(content)

print(f"Generated migration with {len(stmts)} statements.")
