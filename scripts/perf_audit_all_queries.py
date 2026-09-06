import os
import re

repos_dir = 'lib'
unbounded = []
all_selects = []

for root, dirs, files in os.walk(repos_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                # find all occurrences of .from('...')
                matches = re.finditer(r"\.from\(['\"](\w+)['\"]\)", content)
                for m in matches:
                    tbl = m.group(1)
                    pos = m.end()
                    semicolon = content.find(';', pos)
                    if semicolon != -1:
                        chain = content[pos:semicolon]
                    else:
                        chain = content[pos:pos+200]
                    
                    if '.select' in chain:
                        # find line number
                        line_no = content[:m.start()].count('\n') + 1
                        has_limit = any(k in chain for k in ['.limit(', '.range(', '.single()', '.maybeSingle()', '.count('])
                        is_stream = '.stream(' in chain
                        clean_chain = ' '.join(chain.split())[:120]
                        all_selects.append((file, line_no, tbl, has_limit, is_stream, clean_chain))
                        if not has_limit and not is_stream:
                            unbounded.append((file, line_no, tbl, clean_chain))

print(f"Total .from('...').select calls in entire lib: {len(all_selects)}")
print(f"Bounded queries: {len(all_selects) - len(unbounded)}")
print(f"UNBOUNDED queries (no limit, no range, no single): {len(unbounded)}")

print("\n--- CRITICAL UNBOUNDED QUERIES (NO LIMIT) ---")
for u in unbounded:
    print(f"{u[0]}:{u[1]} Table: [{u[2]}] -> {u[3]}")
