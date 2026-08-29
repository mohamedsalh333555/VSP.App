import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = """
SELECT 'app_config' as tbl, count(*) FROM public.app_config
UNION ALL
SELECT 'app_settings', count(*) FROM public.app_settings
UNION ALL
SELECT 'users', count(*) FROM public.users
UNION ALL
SELECT 'stadiums', count(*) FROM public.stadiums
UNION ALL
SELECT 'bookings', count(*) FROM public.bookings
UNION ALL
SELECT 'transactions', count(*) FROM public.transactions
UNION ALL
SELECT 'payout_settlements', count(*) FROM public.payout_settlements
UNION ALL
SELECT 'notifications', count(*) FROM public.notifications
UNION ALL
SELECT 'chat_messages', count(*) FROM public.chat_messages
UNION ALL
SELECT 'teams', count(*) FROM public.teams
UNION ALL
SELECT 'championships', count(*) FROM public.championships;
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
    data = json.loads(resp.read())
    print("CURRENT ROW COUNTS:")
    for r in data:
        print(f" - {r['tbl']}: {r['count']}")
