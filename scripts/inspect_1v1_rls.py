import urllib.request, json

env = json.load(open('env.json'))
token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def run_sql(query):
    req = urllib.request.Request(
        url,
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0"
        },
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

print("=== CURRENT RLS POLICIES ON vsp_1v1_tournament_players ===")
policies = run_sql("""
SELECT policyname, permissive, roles, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'vsp_1v1_tournament_players';
""")
print(json.dumps(policies, indent=2, ensure_ascii=False))

print("=== TABLE RLS STATUS ===")
rls_status = run_sql("""
SELECT relname, relrowsecurity, relforcerowsecurity 
FROM pg_class 
WHERE relname = 'vsp_1v1_tournament_players';
""")
print(json.dumps(rls_status, indent=2))
