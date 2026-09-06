import os
import re

select_pattern = re.compile(r'\.select\((.*?)\)')
repos_dir = 'lib'
select_calls = []

for root, dirs, files in os.walk(repos_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                for idx, line in enumerate(lines):
                    if '.select(' in line or '.select()' in line:
                        clean_line = line.strip()
                        select_calls.append((filepath, idx + 1, clean_line))

select_stars = [s for s in select_calls if "select('*')" in s[2] or ".select()" in s[2]]

print(f"Total .select calls: {len(select_calls)}")
print(f"Total .select('*') or .select() (full row fetch): {len(select_stars)}")

print("\n--- SAMPLE FULL-ROW FETCHES IN CORE REPOSITORIES / SCREENS ---")
for s in select_stars[:35]:
    # Normalize path
    p = s[0].replace('\\', '/')
    print(f"{p}:{s[1]} -> {s[2]}")
