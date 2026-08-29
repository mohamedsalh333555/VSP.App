import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = """
SELECT id, name, price_per_hour, base_price, is_verified, is_blocked 
FROM public.stadiums;
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
    print("STADIUMS AUDIT IN LIVE DATABASE:")
    print("-" * 60)
    for s in data:
        print(f"🏟️ Name: {s.get('name')}")
        print(f"   ID: {s.get('id')}")
        print(f"   price_per_hour: {s.get('price_per_hour')}")
        print(f"   base_price: {s.get('base_price')}")
        print(f"   is_verified: {s.get('is_verified')} | is_blocked: {s.get('is_blocked')}")
        print("-" * 60)
