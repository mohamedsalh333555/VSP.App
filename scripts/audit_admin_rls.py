import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

service_key = env["SUPABASE_SERVICE_ROLE_KEY"]
url_base = env["SUPABASE_URL"] + "/rest/v1"

# Target tables used by admin panel
target_tables = [
    "users",
    "stadiums",
    "bookings",
    "transactions",
    "payout_settlements",
    "banners",
    "app_config",
    "app_settings",
    "championships",
    "vsp_1v1_tournaments",
    "vsp_1v1_tournament_players",
    "vsp_1v1_registrations",
    "reports",
    "reviews",
    "notifications"
]

print("=== CHECKING PERMISSIONS FOR AUTHENTICATED ADMIN USERS ===")
print("Testing SELECT permissions as an authenticated user with admin role...")

# Let's check who the admin accounts are in the database
req_users = urllib.request.Request(
    url_base + "/users?role=in.(admin,co_founder,cofounder)&select=id,name,email,role",
    headers={"apikey": service_key, "Authorization": f"Bearer {service_key}"}
)
with urllib.request.urlopen(req_users) as resp:
    admins = json.loads(resp.read().decode("utf-8"))
    print(f"Found {len(admins)} Admin/Co-founder accounts:")
    for a in admins:
        print(f" - {a.get('name')} | {a.get('email')} | role: {a.get('role')} | id: {a.get('id')}")

# Now let's test if an admin user token can read/write each table
# We can simulate the RLS check by looking at pg_policies via RPC or querying tables
