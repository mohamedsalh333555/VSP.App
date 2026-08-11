import os
import re

SPECIFIC_REPLACEMENTS = [
    ("Iconsax.messages_3Plus", "Iconsax.messages_3"),
    ("Iconsax.clockOff", "Iconsax.clock"),
    ("Iconsax.calendar_1Check", "Iconsax.calendar_1"),
    ("Iconsax.calendar_1Day", "Iconsax.calendar_1"),
    ("Iconsax.calendar_1Week", "Iconsax.calendar_1"),
    ("Iconsax.notificationOff", "Iconsax.notification"),
    ("LucideIcons.calendarCheck", "Iconsax.calendar_1"),
    ("LucideIcons.calendarClock", "Iconsax.calendar_1"),
    ("LucideIcons.calendarDays", "Iconsax.calendar_1"),
    ("LucideIcons.calendarRange", "Iconsax.calendar_1"),
    ("LucideIcons.calendarX", "Iconsax.calendar_1"),
    ("LucideIcons.clockOff", "Iconsax.clock"),
    ("LucideIcons.messageSquarePlus", "Iconsax.messages_3"),
    ("LucideIcons.bellOff", "Iconsax.notification"),
    ("LucideIcons.shieldAlert", "Iconsax.security_safe"),
    ("LucideIcons.shieldCheck", "Iconsax.security_safe"),
    ("LucideIcons.sparkles", "Iconsax.magic_star"),
    ("LucideIcons.crown", "Iconsax.crown"),
    ("FontAwesomeIcons.crown", "Iconsax.crown"),
    ("FontAwesomeIcons.circleExclamation", "Iconsax.warning_2"),
    ("FontAwesomeIcons.userGroup", "Iconsax.people"),
    ("FontAwesomeIcons.clockHistory", "Iconsax.rotate_left"),
    ("FontAwesomeIcons.trophyStar", "Iconsax.cup"),
    ("FontAwesomeIcons.trophy", "Iconsax.cup"),
    ("FontAwesomeIcons.futbol", "Iconsax.element_4"),
    ("FontAwesomeIcons.shieldHalved", "Iconsax.security_safe"),
    ("FontAwesomeIcons.fire", "Iconsax.flash_1"),
    ("FontAwesomeIcons.trashCan", "Iconsax.trash"),
    ("FontAwesomeIcons.ban", "Iconsax.close_circle"),
    ("FontAwesomeIcons.personRunning", "Iconsax.user"),
]

def fix_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    original = content

    # Clean imports
    content = re.sub(r"import\s+['\"]package:lucide_icons_flutter/[^'\"]+['\"];", "import 'package:iconsax_flutter/iconsax_flutter.dart';", content)
    content = re.sub(r"import\s+['\"]package:font_awesome_flutter/[^'\"]+['\"];", "import 'package:iconsax_flutter/iconsax_flutter.dart';", content)
    content = re.sub(r"import\s+['\"]package:cupertino_icons/[^'\"]+['\"];", "import 'package:iconsax_flutter/iconsax_flutter.dart';", content)

    # Specific symbol replacements
    for old_sym, new_sym in SPECIFIC_REPLACEMENTS:
        content = content.replace(old_sym, new_sym)

    # Any remaining LucideIcons.xxx -> Iconsax.xxx
    content = re.sub(r"LucideIcons\.([a-zA-Z0-9_]+)", r"Iconsax.\1", content)
    # Any remaining FontAwesomeIcons.xxx -> Iconsax.xxx
    content = re.sub(r"FontAwesomeIcons\.([a-zA-Z0-9_]+)", r"Iconsax.\1", content)

    # Ensure iconsax import
    if "Iconsax." in content and "import 'package:iconsax_flutter/iconsax_flutter.dart';" not in content:
        content = "import 'package:iconsax_flutter/iconsax_flutter.dart';\n" + content

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
    print(f"Fixed remaining icons in {mod_count} files.")

if __name__ == "__main__":
    main()
