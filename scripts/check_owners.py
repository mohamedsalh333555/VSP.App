import json
import urllib.request

with open('env.json', 'r', encoding='utf-8') as f:
    env = json.load(f)

URL = env['SUPABASE_URL']
KEY = env['SUPABASE_SERVICE_ROLE_KEY']
headers = {
    'apikey': KEY,
    'Authorization': f'Bearer {KEY}'
}

def fetch(endpoint):
    req = urllib.request.Request(f"{URL}/rest/v1/{endpoint}", headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode('utf-8'))

users = fetch("users?select=*")
stadiums = fetch("stadiums?select=*")

print("=" * 60)
print(f"TOTAL USERS: {len(users)}")
print("=" * 60)
for u in users:
    print(f"ID: {u.get('id')}")
    print(f"  Name: {u.get('name')}")
    print(f"  Role: {u.get('role')}")
    print(f"  Email: {u.get('email')}")
    print(f"  Phone: {u.get('phone')}")
    print(f"  Has Stadium Flag: {u.get('has_stadium')}")
    print("-" * 40)

print("\n" + "=" * 60)
print(f"TOTAL STADIUMS: {len(stadiums)}")
print("=" * 60)
for s in stadiums:
    owner_id = s.get('owner_id')
    owner = next((u for u in users if u.get('id') == owner_id), None)
    owner_name = owner.get('name') if owner else "Unknown"
    print(f"Stadium ID: {s.get('id')}")
    print(f"  Name: {s.get('name')}")
    print(f"  Owner ID: {owner_id}")
    print(f"  Owner Name: {owner_name}")
    print(f"  Location: {s.get('location')} - {s.get('governorate')}")
    print(f"  Price/hr: {s.get('price_per_hour')}")
    print("-" * 40)
