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

for name in ['record_1v1_refund_status_atomic', 'record_tournament_refund_status_atomic']:
    res = run_sql(f"SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = '{name}';")
    print(f"=== {name} ===")
    if res and len(res) > 0:
        print(res[0]['def'])
    else:
        print(f"Function {name} not found!")
