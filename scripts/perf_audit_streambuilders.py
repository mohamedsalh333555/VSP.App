import os
import re

repos_dir = 'lib'
bad_streambuilders = []

pattern = re.compile(r'StreamBuilder[^\(]*\(\s*stream:\s*([A-Za-z0-9_]+Repository\(\)\.[A-Za-z0-9_]+\([^\)]*\))', re.MULTILINE)

for root, dirs, files in os.walk(repos_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                matches = pattern.finditer(content)
                for m in matches:
                    line_no = content[:m.start()].count('\n') + 1
                    bad_streambuilders.append((file, line_no, m.group(1)))

print(f"Total inline StreamBuilder stream instantiations: {len(bad_streambuilders)}")
for b in bad_streambuilders:
    print(f"{b[0]}:{b[1]} -> stream: {b[2]}")
