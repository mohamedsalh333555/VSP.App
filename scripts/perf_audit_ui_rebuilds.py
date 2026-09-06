import os
import re

repos_dir = 'lib'
listview_raw = []
gridview_raw = []
provider_broad = []
opacity_widgets = []

for root, dirs, files in os.walk(repos_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                for idx, line in enumerate(lines):
                    l = line.strip()
                    # ListView check
                    if re.search(r'\bListView\s*\(', l) and not 'ListView.builder' in l and not 'ListView.separated' in l:
                        listview_raw.append((file, idx + 1, l))
                    # GridView check
                    if re.search(r'\bGridView\s*\(', l) and not 'GridView.builder' in l and not 'GridView.count' in l:
                        gridview_raw.append((file, idx + 1, l))
                    # Provider check
                    if 'Provider.of<' in l and 'listen: false' not in l and 'listen:false' not in l:
                        provider_broad.append((file, idx + 1, l))
                    if 'context.watch<' in l:
                        provider_broad.append((file, idx + 1, l))
                    # Opacity widget
                    if re.search(r'\bOpacity\s*\(', l) and not 'AnimatedOpacity' in l:
                        opacity_widgets.append((file, idx + 1, l))

print(f"Raw ListView() [eager instantiation of children]: {len(listview_raw)}")
print(f"Raw GridView() [eager instantiation]: {len(gridview_raw)}")
print(f"Broad Provider watches (rebuilding entire widget on any state change): {len(provider_broad)}")
print(f"Heavy Opacity widgets [creates dedicated compositing layer / offscreen buffer]: {len(opacity_widgets)}")

print("\n--- SAMPLE RAW ListView() CALLS ---")
for x in listview_raw[:15]:
    print(f"{x[0]}:{x[1]} -> {x[2]}")

print("\n--- SAMPLE HEAVY Opacity() CALLS ---")
for x in opacity_widgets[:15]:
    print(f"{x[0]}:{x[1]} -> {x[2]}")
