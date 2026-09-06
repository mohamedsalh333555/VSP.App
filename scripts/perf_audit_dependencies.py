import os
import re

deps = []
with open('pubspec.yaml', 'r') as f:
    in_deps = False
    for line in f:
        if line.startswith('dependencies:'):
            in_deps = True
            continue
        if in_deps:
            if line.startswith('dev_dependencies:') or (line.strip() and not line.startswith(' ') and not line.startswith('  ')):
                break
            m = re.match(r'^\s{2}([a-zA-Z0-9_]+):', line)
            if m:
                deps.append(m.group(1))
lib_imports = set()

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            with open(os.path.join(root, file), 'r', encoding='utf-8', errors='ignore') as df:
                for line in df:
                    if line.startswith('import '):
                        if 'package:' in line:
                            pkg_name = line.split('package:')[1].split('/')[0]
                            lib_imports.add(pkg_name)

print("--- PACKAGES IN pubspec.yaml AND THEIR USAGE STATUS ---")
for dep in deps:
    if dep in ['flutter', 'flutter_web_plugins', 'flutter_localizations']:
        continue
    status = "USED" if dep in lib_imports else "POTENTIALLY UNUSED (No direct import in lib/)"
    print(f"{dep:<28} -> {status}")
