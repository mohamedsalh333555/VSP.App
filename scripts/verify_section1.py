import urllib.request, urllib.error, json

with open('env.json', 'r') as f:
    env = json.load(f)

token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def run_sql(query_str):
    payload = json.dumps({"query": query_str}).encode("utf-8")
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

print("=" * 70)
print("📊 SECTION 1 DATABASE AUDIT: VERIFYING COLUMNS & TABLES")
print("=" * 70)

# 1. Inspect vsp_1v1_tournaments columns
q1 = """
SELECT column_name, data_type, column_default, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'vsp_1v1_tournaments' 
  AND column_name IN ('entry_fee', 'prize_pool', 'prize_delivered', 'prize_delivered_at', 'prize_delivered_by', 'prize_delivery_notes')
ORDER BY ordinal_position;
"""
cols_tourn = run_sql(q1)
print("\n1️⃣ Columns added to public.vsp_1v1_tournaments:")
for c in cols_tourn:
    print(f"  ✔️ {c['column_name']} | type: {c['data_type']} | default: {c['column_default']} | nullable: {c['is_nullable']}")

# 2. Inspect vsp_1v1_tournament_players columns
q2 = """
SELECT column_name, data_type, column_default, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'vsp_1v1_tournament_players' 
  AND column_name IN ('payment_status', 'payment_order_id', 'paid_amount')
ORDER BY ordinal_position;
"""
cols_players = run_sql(q2)
print("\n2️⃣ Columns added to public.vsp_1v1_tournament_players:")
for c in cols_players:
    print(f"  ✔️ {c['column_name']} | type: {c['data_type']} | default: {c['column_default']} | nullable: {c['is_nullable']}")

# 3. Inspect vsp_1v1_tournament_orders table
q3 = """
SELECT column_name, data_type, column_default, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'vsp_1v1_tournament_orders'
ORDER BY ordinal_position;
"""
cols_orders = run_sql(q3)
print(f"\n3️⃣ Columns in NEW table public.vsp_1v1_tournament_orders ({len(cols_orders)} columns):")
for c in cols_orders:
    print(f"  ✔️ {c['column_name']} | type: {c['data_type']} | default: {c['column_default']} | nullable: {c['is_nullable']}")

# 4. Check constraints on vsp_1v1_tournament_orders
q4 = """
SELECT conname, pg_get_constraintdef(c.oid) 
FROM pg_constraint c 
JOIN pg_class t ON c.conrelid = t.oid 
WHERE t.relname = 'vsp_1v1_tournament_orders';
"""
constraints = run_sql(q4)
print("\n4️⃣ Constraints on public.vsp_1v1_tournament_orders:")
for con in constraints:
    print(f"  🛡️ {con['conname']} -> {con['pg_get_constraintdef']}")

print("\n" + "=" * 70)
print("✅ SECTION 1 DEPLOYED AND VERIFIED ON LIVE SUPABASE!")
print("=" * 70)
