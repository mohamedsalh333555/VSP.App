import json
import urllib.request
import urllib.error

with open('env.json', 'r') as f:
    env = json.load(f)

URL = env['SUPABASE_URL']
KEY = env['SUPABASE_SERVICE_ROLE_KEY']

def test_connection():
    # Query public.users using PostgREST admin service key
    req = urllib.request.Request(
        f"{URL}/rest/v1/users?select=count",
        headers={
            "apikey": KEY,
            "Authorization": f"Bearer {KEY}",
            "Range": "0-0",
            "Prefer": "count=exact"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            content_range = resp.headers.get('Content-Range', 'unknown')
            print(f"✅ Connection successful! Status: {resp.status}, Users count range: {content_range}")
            return True
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False

if __name__ == '__main__':
    test_connection()
