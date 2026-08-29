import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = """
SELECT 
    'auth.users' as target, count(*) as row_count FROM auth.users
UNION ALL
SELECT 'storage.objects', count(*) FROM storage.objects
UNION ALL
SELECT 'public.users', count(*) FROM public.users
UNION ALL
SELECT 'public.stadiums', count(*) FROM public.stadiums
UNION ALL
SELECT 'public.bookings', count(*) FROM public.bookings
UNION ALL
SELECT 'public.transactions', count(*) FROM public.transactions
UNION ALL
SELECT 'public.payout_settlements', count(*) FROM public.payout_settlements
UNION ALL
SELECT 'public.notifications', count(*) FROM public.notifications
UNION ALL
SELECT 'public.chat_messages', count(*) FROM public.chat_messages
UNION ALL
SELECT 'public.conversations', count(*) FROM public.conversations
UNION ALL
SELECT 'public.teams', count(*) FROM public.teams
UNION ALL
SELECT 'public.championships', count(*) FROM public.championships
UNION ALL
SELECT 'public.reviews', count(*) FROM public.reviews
UNION ALL
SELECT 'public.financial_audit_logs', count(*) FROM public.financial_audit_logs;
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

with urllib.request.urlopen(req) as resp:
    counts = json.loads(resp.read())
    print("=" * 60)
    print("🔍 LIVE DATABASE AUDIT AFTER PURGE (ROW COUNTS):")
    print("=" * 60)
    total_remaining_rows = 0
    for c in counts:
        cnt = c['row_count']
        total_remaining_rows += cnt
        print(f"✔️ {c['target']:<30}: {cnt} rows")
    print("=" * 60)
    print(f"🎉 TOTAL ROWS ACROSS ALL TABLES: {total_remaining_rows}")
    print("=" * 60)
