import os
import re

repos_dir = 'lib'
image_networks = []
cached_images = []
upload_calls = []

for root, dirs, files in os.walk(repos_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.splitlines()
                for idx, line in enumerate(lines):
                    l = line.strip()
                    if 'Image.network(' in l:
                        image_networks.append((file, idx + 1, l))
                    if 'CachedNetworkImage(' in l:
                        cached_images.append((file, idx + 1, l))
                    if 'upload(' in l or 'uploadBinary(' in l:
                        upload_calls.append((file, idx + 1, l))

print(f"Total Image.network (UNCLEAN / UNCACHED): {len(image_networks)}")
print(f"Total CachedNetworkImage (CACHED): {len(cached_images)}")
print(f"Upload calls found: {len(upload_calls)}")

print("\n--- SAMPLE Image.network CALLS ---")
for x in image_networks[:20]:
    print(f"{x[0]}:{x[1]} -> {x[2]}")

print("\n--- SAMPLE UPLOAD CALLS ---")
for x in upload_calls:
    print(f"{x[0]}:{x[1]} -> {x[2]}")
