import urllib.request
import json
import sys

env = json.load(open('env.json'))
token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def run_sql(query):
    req = urllib.request.Request(
        url,
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0"
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = resp.read().decode("utf-8")
            if not data:
                return []
            return json.loads(data)
    except urllib.error.HTTPError as e:
        err_content = e.read().decode("utf-8")
        print(f"HTTPError {e.code}: {err_content}", file=sys.stderr)
        raise

if __name__ == "__main__":
    if len(sys.argv) > 1:
        query = sys.argv[1]
        res = run_sql(query)
        print(json.dumps(res, indent=2, ensure_ascii=False))
