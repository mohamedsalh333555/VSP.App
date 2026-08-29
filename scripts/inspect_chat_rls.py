import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = """
SELECT tablename, policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename IN ('notifications', 'chat_messages', 'conversations')
ORDER BY tablename, cmd;
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
    print("LIVE RLS POLICIES FOR CHAT & NOTIFICATIONS:")
    print("=" * 80)
    for p in data:
        print(f"📋 Table:   {p.get('tablename')}")
        print(f"   Policy:  {p.get('policyname')} ({p.get('cmd')})")
        print(f"   USING:   {p.get('qual')}")
        print(f"   CHECK:   {p.get('with_check')}")
        print("-" * 80)
