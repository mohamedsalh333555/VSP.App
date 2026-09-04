import urllib.request
import json

def run_query(sql):
    with open("env.json", "r") as f:
        env = json.load(f)
    token = env["SUPABASE_MANAGEMENT_KEY"]
    project_ref = "mktqkddbcddrxjxabdua"
    url = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"
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
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

print("=== 1. SECURITY ADVISOR: Functions executable by anon ===")
anon_fns = run_query("""
    SELECT 
        p.proname,
        pg_get_function_identity_arguments(p.oid) as args,
        p.prosecdef as is_security_definer
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
    ORDER BY p.proname;
""")
print(f"Total functions executable by anon: {len(anon_fns)}")
for f in anon_fns[:10]:
    print(f" - {f['proname']}({f['args']}) | Security Definer: {f['is_security_definer']}")
if len(anon_fns) > 10:
    print(f" ... and {len(anon_fns) - 10} more.")

print("\n=== 2. PERFORMANCE ADVISOR: Policies with auth.uid() instead of (select auth.uid()) ===")
auth_uid_pols = run_query("""
    SELECT 
        schemaname,
        tablename,
        policyname,
        qual,
        with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (qual ~* '(?<!select\\s)auth\\.uid\\(\\)' OR with_check ~* '(?<!select\\s)auth\\.uid\\(\\)');
""")
print(f"Total policies using auth.uid(): {len(auth_uid_pols)}")

print("\n=== 3. PERFORMANCE ADVISOR: Unindexed Foreign Keys ===")
unindexed_fks = run_query("""
    SELECT
        c.conrelid::regclass AS table_name,
        c.conname AS fk_name,
        pg_get_constraintdef(c.oid) AS fk_def
    FROM pg_constraint c
    JOIN pg_namespace n ON n.oid = c.connamespace
    WHERE n.nspname = 'public'
      AND c.contype = 'f'
      AND NOT EXISTS (
          SELECT 1
          FROM pg_index i
          WHERE i.indrelid = c.conrelid
            AND (i.indkey::int2[])[0:cardinality(c.conkey)-1] = c.conkey
      );
""")
print(f"Total unindexed foreign keys: {len(unindexed_fks)}")
for fk in unindexed_fks:
    print(f" - {fk['table_name']}: {fk['fk_name']} -> {fk['fk_def']}")

print("\n=== 4. SECURITY ADVISOR: Function search_path mutable ===")
mutable_search_paths = run_query("""
    SELECT 
        p.proname,
        pg_get_function_identity_arguments(p.oid) as args,
        p.proconfig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND (p.proconfig IS NULL OR NOT array_to_string(p.proconfig, ',') ~* 'search_path=');
""")
print(f"Security definer functions without search_path: {len(mutable_search_paths)}")
for m in mutable_search_paths:
    print(f" - {m['proname']}({m['args']})")
