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

print("=== CHECKING CHAMPIONSHIPS FUNCTIONS ON LIVE DB ===")
funcs = run_sql("""
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname IN (
    'generate_tournament_bracket_atomic',
    'prepare_tournament_bracket_atomic',
    'join_championship_atomic',
    'confirm_tournament_order_atomic',
    'crown_tournament_champion_atomic',
    'leave_championship_atomic'
);
""")

for f in funcs:
    print(f"Function: {f['proname']}")
    src = f.get('prosrc', '')
    if 'generate_tournament_bracket_atomic' in f['proname']:
        print("  -> Has score protection:", 'is_completed = true OR home_score IS NOT NULL' in src)
        print("  -> Uses paid_teams:", 'v_champ.paid_teams' in src)
    if 'join_championship_atomic' in f['proname']:
        print("  -> Checks entry_fee > 0:", 'entry_fee > 0' in src)
    if 'confirm_tournament_order_atomic' in f['proname']:
        print("  -> Checks over-capacity / max_teams:", 'max_teams' in src or 'team_count' in src)
