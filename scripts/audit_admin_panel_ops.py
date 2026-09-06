import os
import re

dir_path = r"..\vsp_admin_panel\src"
from_patterns = set()
rpc_patterns = set()

for root, dirs, files in os.walk(dir_path):
    for f in files:
        if f.endswith(('.js', '.jsx', '.ts', '.tsx')):
            filepath = os.path.join(root, f)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as fp:
                    content = fp.read()
                    matches = re.findall(r"\.from\(['\"]([a-zA-Z0-9_-]+)['\"]\)\.([a-zA-Z0-9_]+)", content)
                    for table, op in matches:
                        from_patterns.add((table, op, f))
                    rpcs = re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_-]+)['\"]", content)
                    for rpc in rpcs:
                        rpc_patterns.add((rpc, f))
            except Exception as e:
                pass

print("=== ALL TABLES & OPERATIONS CALLED IN ADMIN PANEL ===")
table_ops = {}
for t, op, file in sorted(from_patterns):
    if t not in table_ops:
        table_ops[t] = set()
    table_ops[t].add(op)

for t, ops in sorted(table_ops.items()):
    print(f"  📁 {t:<30} -> {sorted(ops)}")

print("\n=== ALL RPCS CALLED IN ADMIN PANEL ===")
for rpc, f in sorted(rpc_patterns):
    print(f"  ⚡ {rpc:<38} in {f}")
