import os

GETTER_MAP = {
    "Iconsax.tick_circleCheck": "Iconsax.tick_circle",
    "Iconsax.eyeOff": "Iconsax.eye_slash",
    "Iconsax.smsOpen": "Iconsax.sms",
    "Iconsax.uploadCloud": "Iconsax.export_3",
    "Iconsax.upload": "Iconsax.export_3",
    "Iconsax.lightbulb": "Iconsax.flash_1",
    "Iconsax.building2": "Iconsax.building",
    "Iconsax.ban": "Iconsax.close_circle",
    "Iconsax.fileSignature": "Iconsax.document_text",
    "Iconsax.barChart3": "Iconsax.chart_1",
    "Iconsax.setting_22": "Iconsax.setting_2",
    "Iconsax.smartphone": "Iconsax.mobile",
    "Iconsax.rocket": "Iconsax.flash_1",
    "Iconsax.contact": "Iconsax.user",
    "Iconsax.badgeCheck": "Iconsax.verify",
    "Iconsax.plus": "Iconsax.add_circle",
    "Iconsax.wandMagicSparkles": "Iconsax.magic_star",
    "Iconsax.hash": "Iconsax.tag",
    "Iconsax.gavel": "Iconsax.judge",
    "Iconsax.circle": "Iconsax.tick_circle",
    "Iconsax.playCircle": "Iconsax.play_circle",
    "Iconsax.database": "Iconsax.data",
    "Iconsax.showerHead": "Iconsax.drop",
    "Iconsax.shirt": "Iconsax.tag",
    "Iconsax.sofa": "Iconsax.home",
    "Iconsax.frown": "Iconsax.warning_2",
    "Iconsax.circleCheck": "Iconsax.tick_circle",
    "Iconsax.circleXmark": "Iconsax.close_circle",
}

def fix_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    original = content

    for old_g, new_g in GETTER_MAP.items():
        content = content.replace(old_g, new_g)

    # Remove duplicate import if any
    if "import 'package:iconsax_flutter/iconsax_flutter.dart';" in content:
        lines = content.splitlines()
        new_lines = []
        seen = False
        for line in lines:
            if line.strip() == "import 'package:iconsax_flutter/iconsax_flutter.dart';":
                if not seen:
                    new_lines.append(line)
                    seen = True
            else:
                new_lines.append(line)
        content = "\n".join(new_lines) + ("\n" if content.endswith("\n") else "")

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
                if fix_file(os.path.join(root, file)):
                    mod_count += 1
    print(f"Fixed final getters in {mod_count} files.")

if __name__ == "__main__":
    main()
