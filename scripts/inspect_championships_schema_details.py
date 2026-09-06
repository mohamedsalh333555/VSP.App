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

print("=== CHAMPIONSHIPS COLUMNS ===")
cols = run_sql("SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name = 'championships';")
for c in cols:
    print(f"  {c['column_name']} ({c['data_type']}) default: {c['column_default']}")

print("\n=== TOURNAMENT_ORDERS COLUMNS & CONSTRAINTS ===")
ord_cols = run_sql("SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name = 'tournament_orders';")
for c in ord_cols:
    print(f"  {c['column_name']} ({c['data_type']})")

constraints = run_sql("SELECT conname, pg_get_constraintdef(oid) as def FROM pg_constraint WHERE conrelid = 'tournament_orders'::regclass;")
for c in constraints:
    print(f"  Constraint: {c['conname']} -> {c['def']}")
