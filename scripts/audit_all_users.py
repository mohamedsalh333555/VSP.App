import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = "SELECT id, email, name, role, created_at FROM public.users ORDER BY created_at;"

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
    print("ALL ACCOUNTS IN LIVE DATABASE:")
    print("=" * 70)
    for u in data:
        print(f"👤 Name: {u.get('name')} | 📧 Email: {u.get('email')} | 👑 Role: {u.get('role')}")
    print(f"Total accounts in DB: {len(data)}")
