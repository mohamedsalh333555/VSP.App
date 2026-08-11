import os
import re

IMPORT_REPLACEMENTS = [
    ("import 'package:lucide_icons_flutter/lucide_icons.dart';", "import 'package:iconsax_flutter/iconsax_flutter.dart';"),
    ('import "package:lucide_icons_flutter/lucide_icons.dart";', "import 'package:iconsax_flutter/iconsax_flutter.dart';"),
    ("import 'package:font_awesome_flutter/font_awesome_flutter.dart';", "import 'package:iconsax_flutter/iconsax_flutter.dart';"),
    ('import "package:font_awesome_flutter/font_awesome_flutter.dart";', "import 'package:iconsax_flutter/iconsax_flutter.dart';"),
    ("import 'package:cupertino_icons/cupertino_icons.dart';", "import 'package:iconsax_flutter/iconsax_flutter.dart';"),
]

SYMBOL_MAPPINGS = {
    # Navigation & Directions
    "LucideIcons.chevronLeft": "Iconsax.arrow_left_2",
    "LucideIcons.chevronRight": "Iconsax.arrow_right_3",
    "LucideIcons.chevronDown": "Iconsax.arrow_down_1",
    "LucideIcons.chevronUp": "Iconsax.arrow_up_1",
    "LucideIcons.arrowLeft": "Iconsax.arrow_left",
    "LucideIcons.arrowRight": "Iconsax.arrow_right",
    "FontAwesomeIcons.chevronLeft": "Iconsax.arrow_left_2",
    "FontAwesomeIcons.chevronRight": "Iconsax.arrow_right_3",

    # Users & Authentication
    "LucideIcons.user": "Iconsax.user",
    "LucideIcons.user2": "Iconsax.user",
    "LucideIcons.users": "Iconsax.people",
    "LucideIcons.userPlus": "Iconsax.user_add",
    "LucideIcons.userMinus": "Iconsax.user_remove",
    "LucideIcons.userCheck": "Iconsax.user_tick",
    "LucideIcons.lock": "Iconsax.lock",
    "LucideIcons.unlock": "Iconsax.lock_1",
    "LucideIcons.eye": "Iconsax.eye",
    "LucideIcons.eyeOff": "Iconsax.eye_slash",
    "LucideIcons.mail": "Iconsax.sms",
    "LucideIcons.mailOpen": "Iconsax.sms",
    "LucideIcons.phone": "Iconsax.call",
    "LucideIcons.phoneCall": "Iconsax.call",
    "LucideIcons.logOut": "Iconsax.logout",
    "FontAwesomeIcons.users": "Iconsax.people",
    "FontAwesomeIcons.userPlus": "Iconsax.user_add",
    "FontAwesomeIcons.userMinus": "Iconsax.user_remove",
    "FontAwesomeIcons.phone": "Iconsax.call",

    # Sports, Trophies & Games
    "LucideIcons.trophy": "Iconsax.cup",
    "FontAwesomeIcons.trophy": "Iconsax.cup",
    "FontAwesomeIcons.futbol": "Iconsax.element_4",
    "LucideIcons.target": "Iconsax.element_4",
    "LucideIcons.volleyball": "Iconsax.element_4",
    "LucideIcons.medal": "Iconsax.award",
    "LucideIcons.award": "Iconsax.award",
    "LucideIcons.zap": "Iconsax.flash_1",
    "LucideIcons.flame": "Iconsax.flash_1",

    # Location & Maps
    "LucideIcons.mapPin": "Iconsax.location",
    "LucideIcons.locate": "Iconsax.gps",
    "LucideIcons.navigation": "Iconsax.gps",
    "LucideIcons.compass": "Iconsax.discover",
    "FontAwesomeIcons.locationDot": "Iconsax.location",

    # Time & Calendar
    "LucideIcons.calendar": "Iconsax.calendar_1",
    "LucideIcons.calendarDays": "Iconsax.calendar_1",
    "LucideIcons.clock": "Iconsax.clock",
    "LucideIcons.timer": "Iconsax.clock",
    "LucideIcons.history": "Iconsax.rotate_left",
    "FontAwesomeIcons.calendar": "Iconsax.calendar_1",
    "FontAwesomeIcons.stopwatch": "Iconsax.clock",
    "FontAwesomeIcons.rotateLeft": "Iconsax.rotate_left",

    # Finance & Booking
    "LucideIcons.creditCard": "Iconsax.wallet_1",
    "LucideIcons.wallet": "Iconsax.wallet_1",
    "LucideIcons.banknote": "Iconsax.card",
    "LucideIcons.landmark": "Iconsax.card",
    "LucideIcons.dollarSign": "Iconsax.money_change",
    "FontAwesomeIcons.moneyBill": "Iconsax.wallet_1",

    # Status & Actions
    "LucideIcons.check": "Iconsax.tick_circle",
    "LucideIcons.checkCircle": "Iconsax.tick_circle",
    "LucideIcons.checkCircle2": "Iconsax.tick_circle",
    "LucideIcons.x": "Iconsax.close_circle",
    "LucideIcons.xCircle": "Iconsax.close_circle",
    "LucideIcons.alertTriangle": "Iconsax.warning_2",
    "LucideIcons.alertCircle": "Iconsax.warning_2",
    "LucideIcons.info": "Iconsax.info_circle",
    "LucideIcons.plus": "Iconsax.add_circle",
    "LucideIcons.plusCircle": "Iconsax.add_circle",
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
    "LucideIcons.settings2": "Iconsax.setting_2",
    "LucideIcons.image": "Iconsax.image",
    "LucideIcons.imagePlus": "Iconsax.image",
    "LucideIcons.camera": "Iconsax.image",
    "LucideIcons.fileText": "Iconsax.document_text",
    "LucideIcons.fileSpreadsheet": "Iconsax.document_text",
    "LucideIcons.building": "Iconsax.building",
    "LucideIcons.building2": "Iconsax.building",
    "LucideIcons.car": "Iconsax.car",
    "LucideIcons.coffee": "Iconsax.coffee",
    "LucideIcons.wifiOff": "Iconsax.wifi_square",
    "LucideIcons.send": "Iconsax.send_1",
    "LucideIcons.sparkles": "Iconsax.magic_star",
    "LucideIcons.crown": "Iconsax.crown",
    "LucideIcons.shieldCheck": "Iconsax.security_safe",
    "LucideIcons.shieldAlert": "Iconsax.security_safe",
    "LucideIcons.shield": "Iconsax.security_safe",
    "LucideIcons.externalLink": "Iconsax.export_3",
    "LucideIcons.copy": "Iconsax.copy",
    "LucideIcons.checkCheck": "Iconsax.tick_circle",
    "LucideIcons.arrowUpRight": "Iconsax.arrow_up_3",
    "LucideIcons.refreshCw": "Iconsax.rotate_left",
    "LucideIcons.layers": "Iconsax.layer",
    "LucideIcons.helpCircle": "Iconsax.info_circle",
    "LucideIcons.filter": "Iconsax.filter",
    "LucideIcons.globe": "Iconsax.global",
    "LucideIcons.map": "Iconsax.map",
    "LucideIcons.activity": "Iconsax.activity",
    "LucideIcons.trendingUp": "Iconsax.trend_up",
    "LucideIcons.trendingDown": "Iconsax.trend_down",
    "LucideIcons.barChart2": "Iconsax.chart_1",
    "LucideIcons.pieChart": "Iconsax.chart_2",
    "FontAwesomeIcons.xmark": "Iconsax.close_circle",
    "FontAwesomeIcons.minus": "Iconsax.minus_cirlce",
    "FontAwesomeIcons.penToSquare": "Iconsax.edit",
    "FontAwesomeIcons.shareNodes": "Iconsax.share",
    "FontAwesomeIcons.whatsapp": "Iconsax.messages_3",
}

def refactor_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    original = content

    # 1. Imports
    has_old_icon_import = False
    for old_imp, new_imp in IMPORT_REPLACEMENTS:
        if old_imp in content:
            has_old_icon_import = True
            content = content.replace(old_imp, new_imp)

    # If file uses LucideIcons/FontAwesomeIcons without explicit import line (or needs Iconsax import)
    if any(k in content for k in SYMBOL_MAPPINGS.keys()):
        if "import 'package:iconsax_flutter/iconsax_flutter.dart';" not in content:
            # Insert at top of file with other imports
            content = "import 'package:iconsax_flutter/iconsax_flutter.dart';\n" + content

    # 2. Symbols
    for old_sym, new_sym in SYMBOL_MAPPINGS.items():
        content = content.replace(old_sym, new_sym)

    if content != original:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        return True
    return False

def main():
    root_dir = r"k:\.gemini\antigravity\scratch\vsp_application\lib"
    modified_count = 0
    for root, _, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".dart"):
                full_path = os.path.join(root, file)
                if refactor_file(full_path):
                    modified_count += 1
    print(f"Refactored {modified_count} files.")

if __name__ == "__main__":
    main()
