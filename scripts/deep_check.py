import json
import urllib.request

with open('env.json', 'r', encoding='utf-8') as f:
    env = json.load(f)

URL = env['SUPABASE_URL']
KEY = env['SUPABASE_SERVICE_ROLE_KEY']
headers = {'apikey': KEY, 'Authorization': f'Bearer {KEY}'}

def get(path):
    req = urllib.request.Request(f'{URL}/rest/v1/{path}', headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode('utf-8'))

print("=== ALL STADIUMS ===")
stadiums = get('stadiums?select=*')
print(f"Total stadiums: {len(stadiums)}")
for s in stadiums:
    print(json.dumps(s, ensure_ascii=False, indent=2))

print("\n=== ALL USERS ===")
users = get('users?select=*')
print(f"Total users: {len(users)}")
for u in users:
    print(json.dumps(u, ensure_ascii=False, indent=2))

# Also check bookings table
try:
    bookings = get('bookings?select=*')
    print(f"\n=== ALL BOOKINGS: {len(bookings)} ===")
    for b in bookings:
        print(f"Booking: ID={b.get('id')} Stadium={b.get('stadium_id')} User={b.get('user_id')} Status={b.get('status')}")
except Exception as e:
    print("Error bookings:", e)
