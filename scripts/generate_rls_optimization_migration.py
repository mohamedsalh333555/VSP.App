import urllib.request
import json
import re

with open("env.json", "r") as f:
    env = json.load(f)
token = env["SUPABASE_MANAGEMENT_KEY"]
ref = "mktqkddbcddrxjxabdua"
url = f"https://api.supabase.com/v1/projects/{ref}/database/query"

sql = """
    SELECT 
        tablename,
        policyname,
        permissive,
        roles,
        cmd,
        qual,
        with_check
    FROM pg_policies
    WHERE schemaname = 'public'
    ORDER BY tablename, policyname;
"""

req = urllib.request.Request(url, data=json.dumps({'query': sql}).encode('utf-8'), headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {token}', 'User-Agent': 'Mozilla/5.0'}, method='POST')
with urllib.request.urlopen(req) as resp:
    policies = json.loads(resp.read().decode('utf-8'))

def optimize_auth_uid(expr):
    if not expr:
        return expr
    res = re.sub(r'(?<!select\s)auth\.uid\(\)', '(select auth.uid())', expr, flags=re.IGNORECASE)
    res = res.replace('((select auth.uid()))', '(select auth.uid())')
    return res

def format_roles(roles_val):
    if not roles_val:
        return "PUBLIC"
    if isinstance(roles_val, list):
        return ", ".join(roles_val)
    if isinstance(roles_val, str):
        cleaned = roles_val.strip('{}')
        return cleaned if cleaned else "PUBLIC"
    return "PUBLIC"

stmts = []
stmts.append("-- Migration: 202609050004_phase3_optimize_rls_auth_uid_subqueries.sql")
stmts.append("-- Description: Optimize RLS policies by replacing auth.uid() with (select auth.uid()) for query performance.\n")

modified_count = 0

for pol in policies:
    tname = pol['tablename']
    pname = pol['policyname']
    qual = pol['qual']
    with_check = pol['with_check']
    
    needs_qual = qual and re.search(r'(?<!select\s)auth\.uid\(\)', qual, re.IGNORECASE)
    needs_check = with_check and re.search(r'(?<!select\s)auth\.uid\(\)', with_check, re.IGNORECASE)
    
    if needs_qual or needs_check:
        modified_count += 1
        new_qual = optimize_auth_uid(qual)
        new_check = optimize_auth_uid(with_check)
        
        cmd = pol['cmd']
        roles_str = format_roles(pol['roles'])
        permissive = "AS RESTRICTIVE" if pol['permissive'] == 'RESTRICTIVE' else "AS PERMISSIVE"
        
        stmts.append(f"DROP POLICY IF EXISTS \"{pname}\" ON public.\"{tname}\";")
        pol_stmt = f"CREATE POLICY \"{pname}\" ON public.\"{tname}\" {permissive} FOR {cmd} TO {roles_str}"
        if new_qual:
            pol_stmt += f" USING ({new_qual})"
        if new_check:
            pol_stmt += f" WITH CHECK ({new_check})"
        stmts.append(f"{pol_stmt};\n")

content = "\n".join(stmts)
with open("supabase/migrations/202609050004_phase3_optimize_rls_auth_uid_subqueries.sql", "w", encoding="utf-8") as out:
    out.write(content)

print(f"Total policies to optimize: {modified_count}")
print(f"Migration regenerated successfully.")
