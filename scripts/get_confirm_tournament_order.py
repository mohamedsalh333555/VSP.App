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

print("=== CONFIRM_TOURNAMENT_ORDER_ATOMIC DEFINITION ===")
res = run_sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'confirm_tournament_order_atomic';")
if res and len(res) > 0:
    print(res[0]['def'])
else:
    print("Function confirm_tournament_order_atomic not found!")

print("\n=== RECORD_REFUND_STATUS OR SIMILAR FUNCTIONS ===")
r_funcs = run_sql("SELECT proname FROM pg_proc WHERE proname LIKE '%confirm%tournament%' OR proname LIKE '%refund%';")
print(json.dumps(r_funcs, indent=2))
