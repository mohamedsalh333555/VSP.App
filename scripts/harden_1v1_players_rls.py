import urllib.request, json

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
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

print("Updating RLS policy on vsp_1v1_tournament_players...")

sql = """
-- Drop old view policy
DROP POLICY IF EXISTS "Anyone can view tournament players" ON public.vsp_1v1_tournament_players;

-- Re-create with bulletproof security:
-- 1. Public/Players see ONLY paid players
-- 2. The player themselves can see their own row (user_id = auth.uid()) even if pending/unpaid
-- 3. Admins/Co-founders and service_role see all rows
CREATE POLICY "Anyone can view tournament players"
ON public.vsp_1v1_tournament_players
FOR SELECT
TO anon, authenticated
USING (
  (payment_status = 'paid')
  OR (auth.uid() IS NOT NULL AND user_id = auth.uid())
  OR (COALESCE(auth.role(), '') = 'service_role')
  OR (EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'co_founder')
  ))
);
"""

res = run_sql(sql)
print("Result:", res)

# Verify updated policy
p = run_sql("""
SELECT policyname, qual 
FROM pg_policies 
WHERE tablename = 'vsp_1v1_tournament_players' 
  AND policyname = 'Anyone can view tournament players';
""")
print("Verified Policy:", json.dumps(p, indent=2, ensure_ascii=False))
