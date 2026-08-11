import os
import re

def enforce_outline(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    original = content

    # Replace Iconsax.xxx_copy with Iconsax.xxx
    # e.g., Iconsax.home_1_copy -> Iconsax.home_1
    # e.g., Iconsax.user_copy -> Iconsax.user
    content = re.sub(r"Iconsax\.([a-zA-Z0-9_]+)_copy\b", r"Iconsax.\1", content)

    if content != original:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        return True
    return False

def main():
    root_dir = r"k:\.gemini\antigravity\scratch\vsp_application\lib"
    mod_count = 0
    for root, _, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".dart"):
                if enforce_outline(os.path.join(root, file)):
                    mod_count += 1
    print(f"Enforced 100% Outline icons in {mod_count} files.")

if __name__ == "__main__":
    main()
