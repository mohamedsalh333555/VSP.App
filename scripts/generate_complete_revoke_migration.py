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
        p.prosecdef,
        pg_get_function_result(p.oid) as returns
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
    ORDER BY p.proname;
"""

req = urllib.request.Request(url, data=json.dumps({'query': sql}).encode('utf-8'), headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {token}', 'User-Agent': 'Mozilla/5.0'}, method='POST')
with urllib.request.urlopen(req) as resp:
    funcs = json.loads(resp.read().decode('utf-8'))

print(f"Total functions currently executable by anon: {len(funcs)}")

# Cron / internal automations
cron_routines = [
    'auto_reconcile_all_past_bookings',
    'auto_reconcile_past_bookings',
    'auto_reconcile_single_entry_results',
    'auto_expire_pending_locks',
    'auto_expire_stale_records',
    'auto_expire_matchups',
    'auto_downgrade_expired_subscriptions',
    'auto_approve_tournament_matches_24h',
    'auto_expire_pending_bookings',
    'reset_fair_play_score_annually'
]

# Legitimately public functions (allowed for anon)
public_allowed = [
    'global_search',
    'increment_banner_views',
    'increment_banner_clicks',
    'get_nearby_stadiums'
]

stmts = []
stmts.append("-- Migration: 202609050002_phase1_revoke_anon_and_cron_permissions.sql")
stmts.append("-- Lock down all internal, admin, and authenticated routines from anon/PUBLIC.\n")

for f in funcs:
    name = f['proname']
    args = f['args']
    full_ident = f"public.\"{name}\"({args})"
    
    if name in public_allowed:
        continue
    
    if name in cron_routines or name.startswith('auto_'):
        stmts.append(f"REVOKE EXECUTE ON FUNCTION {full_ident} FROM PUBLIC, anon, authenticated;")
        stmts.append(f"GRANT EXECUTE ON FUNCTION {full_ident} TO service_role;\n")
    else:
        stmts.append(f"REVOKE EXECUTE ON FUNCTION {full_ident} FROM PUBLIC, anon;")
        stmts.append(f"GRANT EXECUTE ON FUNCTION {full_ident} TO authenticated, service_role;\n")

content = "\n".join(stmts)
with open("supabase/migrations/202609050002_phase1_revoke_anon_and_cron_permissions.sql", "w", encoding="utf-8") as out:
    out.write(content)

print(f"Generated comprehensive revoke migration with {len(stmts)} statements.")
