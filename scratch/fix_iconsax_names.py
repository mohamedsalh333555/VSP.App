import os
import re

MANGLED_FIXES = {
    "Iconsax.tick_circleCircle2": "Iconsax.tick_circle",
    "Iconsax.tick_circleCircle": "Iconsax.tick_circle",
    "Iconsax.close_circleCircle": "Iconsax.close_circle",
    "Iconsax.calendar_1Days": "Iconsax.calendar_1",
    "Iconsax.calendar_1X": "Iconsax.calendar_1",
    "Iconsax.add_circleCircle": "Iconsax.add_circle",
    "Iconsax.callCall": "Iconsax.call",
    "Iconsax.userPlus": "Iconsax.user_add",
    "Iconsax.userMinus": "Iconsax.user_remove",
    "Iconsax.userCheck": "Iconsax.user_tick",
    "Iconsax.user2": "Iconsax.user",
    "Iconsax.users": "Iconsax.people",
    "Iconsax.imagePlus": "Iconsax.image",
    "Iconsax.checkCircle2": "Iconsax.tick_circle",
    "Iconsax.checkCircle": "Iconsax.tick_circle",
    "Iconsax.xCircle": "Iconsax.close_circle",
    "Iconsax.plusCircle": "Iconsax.add_circle",

    # Remaining Lucide & FontAwesome & Material Icons
    "LucideIcons.chevronLeft": "Iconsax.arrow_left_2",
    "LucideIcons.chevronRight": "Iconsax.arrow_right_3",
    "LucideIcons.chevronDown": "Iconsax.arrow_down_1",
    "LucideIcons.chevronUp": "Iconsax.arrow_up_1",
    "LucideIcons.arrowLeft": "Iconsax.arrow_left",
    "LucideIcons.arrowRight": "Iconsax.arrow_right",
    "LucideIcons.user": "Iconsax.user",
    "LucideIcons.users": "Iconsax.people",
    "LucideIcons.userPlus": "Iconsax.user_add",
    "LucideIcons.userMinus": "Iconsax.user_remove",
    "LucideIcons.userCheck": "Iconsax.user_tick",
    "LucideIcons.lock": "Iconsax.lock",
    "LucideIcons.unlock": "Iconsax.lock_1",
    "LucideIcons.eye": "Iconsax.eye",
    "LucideIcons.eyeOff": "Iconsax.eye_slash",
    "LucideIcons.mail": "Iconsax.sms",
    "LucideIcons.phone": "Iconsax.call",
    "LucideIcons.phoneCall": "Iconsax.call",
    "LucideIcons.logOut": "Iconsax.logout",
    "LucideIcons.trophy": "Iconsax.cup",
    "LucideIcons.target": "Iconsax.element_4",
    "LucideIcons.volleyball": "Iconsax.element_4",
    "LucideIcons.medal": "Iconsax.award",
    "LucideIcons.award": "Iconsax.award",
    "LucideIcons.zap": "Iconsax.flash_1",
    "LucideIcons.flame": "Iconsax.flash_1",
    "LucideIcons.mapPin": "Iconsax.location",
    "LucideIcons.locate": "Iconsax.gps",
    "LucideIcons.navigation": "Iconsax.gps",
    "LucideIcons.compass": "Iconsax.discover",
    "LucideIcons.calendar": "Iconsax.calendar_1",
    "LucideIcons.clock": "Iconsax.clock",
    "LucideIcons.timer": "Iconsax.clock",
    "LucideIcons.history": "Iconsax.rotate_left",
    "LucideIcons.creditCard": "Iconsax.wallet_1",
    "LucideIcons.wallet": "Iconsax.wallet_1",
    "LucideIcons.banknote": "Iconsax.card",
    "LucideIcons.landmark": "Iconsax.card",
    "LucideIcons.dollarSign": "Iconsax.money_change",
    "LucideIcons.check": "Iconsax.tick_circle",
    "LucideIcons.checkCircle": "Iconsax.tick_circle",
    "LucideIcons.x": "Iconsax.close_circle",
    "LucideIcons.alertTriangle": "Iconsax.warning_2",
    "LucideIcons.alertCircle": "Iconsax.warning_2",
    "LucideIcons.info": "Iconsax.info_circle",
    "LucideIcons.plus": "Iconsax.add_circle",
    "LucideIcons.minus": "Iconsax.minus_cirlce",
    "LucideIcons.search": "Iconsax.search_normal",
    "LucideIcons.edit2": "Iconsax.edit",
    "LucideIcons.pencil": "Iconsax.edit",
    "LucideIcons.trash2": "Iconsax.trash",
    "LucideIcons.trash": "Iconsax.trash",
    "LucideIcons.share2": "Iconsax.share",
    "LucideIcons.heart": "Iconsax.heart",
    "LucideIcons.star": "Iconsax.star",
    "LucideIcons.bell": "Iconsax.notification",
    "LucideIcons.bellOff": "Iconsax.notification",
    "LucideIcons.messageSquare": "Iconsax.messages_3",
    "LucideIcons.messageCircle": "Iconsax.messages_3",
    "LucideIcons.headset": "Iconsax.headphone",
    "LucideIcons.sliders": "Iconsax.setting_2",
    "LucideIcons.settings": "Iconsax.setting_2",
    "LucideIcons.image": "Iconsax.image",
    "LucideIcons.fileText": "Iconsax.document_text",
    "LucideIcons.building": "Iconsax.building",
    "LucideIcons.car": "Iconsax.car",
    "LucideIcons.coffee": "Iconsax.coffee",
    "LucideIcons.wifiOff": "Iconsax.wifi_square",

    "FontAwesomeIcons.chevronLeft": "Iconsax.arrow_left_2",
    "FontAwesomeIcons.chevronRight": "Iconsax.arrow_right_3",
    "FontAwesomeIcons.users": "Iconsax.people",
    "FontAwesomeIcons.userPlus": "Iconsax.user_add",
    "FontAwesomeIcons.userMinus": "Iconsax.user_remove",
    "FontAwesomeIcons.phone": "Iconsax.call",
    "FontAwesomeIcons.trophy": "Iconsax.cup",
    "FontAwesomeIcons.futbol": "Iconsax.element_4",
    "FontAwesomeIcons.locationDot": "Iconsax.location",
    "FontAwesomeIcons.calendar": "Iconsax.calendar_1",
    "FontAwesomeIcons.stopwatch": "Iconsax.clock",
    "FontAwesomeIcons.rotateLeft": "Iconsax.rotate_left",
    "FontAwesomeIcons.moneyBill": "Iconsax.wallet_1",
    "FontAwesomeIcons.xmark": "Iconsax.close_circle",
    "FontAwesomeIcons.minus": "Iconsax.minus_cirlce",
    "FontAwesomeIcons.penToSquare": "Iconsax.edit",
    "FontAwesomeIcons.shareNodes": "Iconsax.share",
    "FontAwesomeIcons.whatsapp": "Iconsax.messages_3",
    "FontAwesomeIcons.crown": "Iconsax.crown",
    "FontAwesomeIcons.circleExclamation": "Iconsax.warning_2",
    "FontAwesomeIcons.userGroup": "Iconsax.people",
}

def clean_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    original = content

    # Replace Lucide / FontAwesome imports if any remain
    content = re.sub(r"import\s+['\"]package:lucide_icons_flutter/[^'\"]+['\"];", "import 'package:iconsax_flutter/iconsax_flutter.dart';", content)
    content = re.sub(r"import\s+['\"]package:font_awesome_flutter/[^'\"]+['\"];", "import 'package:iconsax_flutter/iconsax_flutter.dart';", content)
    content = re.sub(r"import\s+['\"]package:cupertino_icons/[^'\"]+['\"];", "import 'package:iconsax_flutter/iconsax_flutter.dart';", content)

    # Ensure iconsax import is present if Iconsax is used
    if "Iconsax." in content and "import 'package:iconsax_flutter/iconsax_flutter.dart';" not in content:
        content = "import 'package:iconsax_flutter/iconsax_flutter.dart';\n" + content

    for k, v in MANGLED_FIXES.items():
        content = content.replace(k, v)

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
                if clean_file(os.path.join(root, file)):
                    mod_count += 1
    print(f"Fixed mangled icons in {mod_count} files.")

if __name__ == "__main__":
    main()
