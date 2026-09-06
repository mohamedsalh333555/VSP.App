import os

repos_dir = 'lib/core/repositories'
unbounded = []
bounded = []

for root, dirs, files in os.walk(repos_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                chunks = content.split('_supabase.from(')
                for chunk in chunks[1:]:
                    first_semicolon = chunk.split(';')[0]
                    if '.select' in first_semicolon:
                        tbl = chunk.split(')')[0].replace("'", "").replace('"', '')
                        has_limit = (
                            '.limit(' in first_semicolon or 
                            '.range(' in first_semicolon or 
                            '.single()' in first_semicolon or 
                            '.maybeSingle()' in first_semicolon
                        )
                        has_stream = '.stream(' in first_semicolon
                        if not has_limit and not has_stream:
                            unbounded.append((file, tbl, ' '.join(first_semicolon.split())[:110]))
                        else:
                            bounded.append((file, tbl))

print(f"Total repository SELECT queries: {len(unbounded) + len(bounded)}")
print(f"Bounded queries (limit/range/single): {len(bounded)}")
print(f"UNBOUNDED queries (NO limit, potential table dump): {len(unbounded)}")

print("\n--- UNBOUNDED QUERIES SAMPLE ---")
for u in unbounded[:25]:
    print(f"File: {u[0]:<28} Table: {u[1]:<20} Query: {u[2]}")
