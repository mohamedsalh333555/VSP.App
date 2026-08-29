import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = "SELECT id, name, entry_fee, grand_prize, owner_id, status FROM public.championships;"

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
    print("CHAMPIONSHIPS IN LIVE DATABASE:")
    print("=" * 70)
    for c in data:
        print(f"🏆 Name: {c.get('name')} | Fee: {c.get('entry_fee')} | Prize: {c.get('grand_prize')} | Status: {c.get('status')}")
    print(f"Total championships: {len(data)}")
