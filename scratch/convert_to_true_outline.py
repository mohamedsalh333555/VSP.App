import os
import re

pub_cache_path = r"C:\Users\pc\AppData\Local\Pub\Cache\hosted\pub.dev\iconsax_flutter-1.0.1\lib\iconsax_flutter.dart"
with open(pub_cache_path, "r", encoding="utf-8") as f:
    iconsax_code = f.read()

copy_getters = set(re.findall(r"static const ([a-zA-Z0-9_]+_copy)\b", iconsax_code))
print(f"Total _copy (Outline) getters in library: {len(copy_getters)}")

base_to_copy = {}
for copy_name in copy_getters:
    base_name = copy_name[:-5]
    base_to_copy[base_name] = copy_name

root_dir = r"k:\.gemini\antigravity\scratch\vsp_application\lib"
modified_files = 0
total_replacements = 0

for root, _, files in os.walk(root_dir):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            
            file_replacements = 0
            def replace_match(m):
                global file_replacements
                icon_name = m.group(1)
                if icon_name.endswith("_copy"):
                    return m.group(0)
                if icon_name in base_to_copy:
                    file_replacements += 1
                    return f"Iconsax.{base_to_copy[icon_name]}"
                return m.group(0)

            # Find Iconsax.xxx
            new_content = re.sub(r"Iconsax\.([a-zA-Z0-9_]+)\b", replace_match, content)
            
            if new_content != content:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(new_content)
                modified_files += 1
                total_replacements += file_replacements

print(f"Converted {total_replacements} icons across {modified_files} files to TRUE Outline (_copy)!")
