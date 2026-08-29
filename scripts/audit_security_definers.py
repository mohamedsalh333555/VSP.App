import os
import re
import glob

sql_files = glob.glob('supabase/**/*.sql', recursive=True) + glob.glob('*.sql')

findings = []

for filepath in sql_files:
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    # Find functions with SECURITY DEFINER
    func_matches = re.finditer(r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z0-9_\.]+)\s*\((.*?)\)\s*RETURNS\s+(.*?)\s+AS\s*\$\$(.*?)\$\$;', content, re.DOTALL | re.IGNORECASE)

    for m in func_matches:
        func_name = m.group(1).strip()
        params = m.group(2).strip()
        body = m.group(4)

        if 'SECURITY DEFINER' in m.group(0).upper():
            has_auth_uid = 'auth.uid()' in body or 'auth.role()' in body or 'current_user' in body
            has_update = 'UPDATE ' in body.upper()
            has_insert = 'INSERT INTO ' in body.upper()
            has_delete = 'DELETE FROM ' in body.upper()
            
            # Check what it updates
            updates_sensitive = False
            sensitive_keywords = ['is_paid', 'status', 'role', 'commission', 'balance', 'payout', 'refund', 'is_blocked', 'subscription']
            found_sensitive = [k for k in sensitive_keywords if k in body.lower()]

            findings.append({
                'file': filepath,
                'func': func_name,
                'params': params,
                'has_auth': has_auth_uid,
                'has_update': has_update,
                'has_delete': has_delete,
                'sensitive': found_sensitive,
                'body_snippet': body[:300].strip()
            })

print(f"Total SECURITY DEFINER functions found: {len(findings)}")
print("\n" + "="*80)
print("FUNCTIONS WITHOUT AUTH CHECK OR UPDATING SENSITIVE FIELDS:")
print("="*80)

for f in findings:
    if not f['has_auth'] or f['func'] == 'public.confirm_cash_booking_atomic':
        print(f"\nFunction: {f['func']}")
        print(f"File: {f['file']}")
        print(f"Auth check present: {f['has_auth']}")
        print(f"Sensitive fields mentioned: {f['sensitive']}")
        print(f"Params: {f['params']}")
        print("-" * 50)
