import os
import re

def replace_in_file(filepath, replacements):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        for old, new in replacements:
            content = content.replace(old, new)
            
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")
    except Exception as e:
        print(f"Error updating {filepath}: {e}")

def add_import(filepath, import_statement):
    if not os.path.exists(filepath):
        return
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        if import_statement not in content:
            # Add import after the last import
            imports = re.findall(r"^import\s+.*;\n", content, re.MULTILINE)
            if imports:
                last_import = imports[-1]
                content = content.replace(last_import, last_import + import_statement + '\n')
            else:
                content = import_statement + '\n' + content
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Added import to {filepath}")
    except Exception as e:
        print(f"Error adding import to {filepath}: {e}")

def fix_syntax_in_stadium_details():
    filepath = 'lib/features/player/screens/stadium_details_screen.dart'
    if not os.path.exists(filepath): return
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Add AppLocalizations import
        if "import 'package:flutter_gen/gen_l10n/app_localizations.dart';" not in content:
            content = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n" + content

        # Fix Syntax Error in _RatingsTab
        content = content.replace("Widget build BuildContext context", "Widget build(BuildContext context)")
        content = content.replace("Widget build BuildContext context {", "Widget build(BuildContext context) {")
        content = content.replace("@override\n  Widget build BuildContext context", "@override\n  Widget build(BuildContext context)")
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed syntax in {filepath}")
    except Exception as e:
        print(f"Error fixing syntax in {filepath}: {e}")

def main():
    # 1. Fix main.dart
    replace_in_file('lib/main.dart', [
        ("const [\n              GlobalMaterialLocalizations.delegate", "[\n              AppLocalizations.delegate,\n              GlobalMaterialLocalizations.delegate"),
        ("const [\n              AppLocalizations.delegate,", "[\n              AppLocalizations.delegate,")
    ])
    add_import('lib/main.dart', "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")

    # 2. Fix stadium_details_screen.dart
    fix_syntax_in_stadium_details()

    # 3. Fix team_dashboard_screen.dart
    add_import('lib/features/player/screens/team_dashboard_screen.dart', "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")
    add_import('lib/features/player/screens/team_dashboard_screen.dart', "import '../../../core/repositories/match_repository.dart';")
    replace_in_file('lib/features/player/screens/team_dashboard_screen.dart', [
        ("DatabaseService().getPublicMatches()", "MatchRepository().getPublicMatches()")
    ])

    # 4. Fix add_player_sheet.dart
    add_import('lib/features/player/widgets/add_player_sheet.dart', "import '../../../core/repositories/user_repository.dart';")
    replace_in_file('lib/features/player/widgets/add_player_sheet.dart', [
        ("DatabaseService().getUserByPhone", "UserRepository().getUserByPhone")
    ])

    # 5. Fix booking_team_selection_sheet.dart
    add_import('lib/features/player/widgets/booking_team_selection_sheet.dart', "import '../../../core/repositories/team_repository.dart';")
    replace_in_file('lib/features/player/widgets/booking_team_selection_sheet.dart', [
        ("DatabaseService().getTeamByCaptainPhone", "TeamRepository().getTeamByCaptainPhone")
    ])

    # 6. Fix create_team_sheet.dart
    add_import('lib/features/player/widgets/create_team_sheet.dart', "import '../../../core/repositories/team_repository.dart';")
    replace_in_file('lib/features/player/widgets/create_team_sheet.dart', [
        ("DatabaseService().createTeam", "TeamRepository().createTeam")
    ])

    # 7. Fix public_match_card.dart
    add_import('lib/shared/widgets/public_match_card.dart', "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")
    add_import('lib/shared/widgets/public_match_card.dart', "import '../../core/repositories/match_repository.dart';")
    add_import('lib/shared/widgets/public_match_card.dart', "import '../../core/repositories/user_repository.dart';")
    replace_in_file('lib/shared/widgets/public_match_card.dart', [
        ("DatabaseService().joinPublicMatch", "MatchRepository().joinPublicMatch"),
        ("DatabaseService().leavePublicMatch", "MatchRepository().leavePublicMatch"),
        ("DatabaseService().getUsersByIds", "UserRepository().getUsersByIds"),
        ("DatabaseService().removeParticipantFromPublicMatch", "MatchRepository().removeParticipantFromPublicMatch"),
        ("DatabaseService().updatePublicMatchHostSpots", "MatchRepository().updatePublicMatchHostSpots")
    ])

    # 8. Fix stadium_card.dart
    add_import('lib/shared/widgets/stadium_card.dart', "import 'package:flutter_gen/gen_l10n/app_localizations.dart';")

    # 9. Fix Tests
    test_files = [
        'test/app_core_logic_test.dart',
        'test/profile_and_1v1_test.dart',
        'test/tournament_logic_test.dart',
        'test/vsp_1v1_league_test.dart'
    ]
    for test_file in test_files:
        if os.path.exists(test_file):
            add_import(test_file, "import 'package:vsp_application/core/repositories/match_repository.dart';")
            add_import(test_file, "import 'package:vsp_application/core/repositories/team_repository.dart';")
            add_import(test_file, "import 'package:vsp_application/core/repositories/tournament_repository.dart';")
            replace_in_file(test_file, [
                ("DatabaseService().joinPublicMatch", "MatchRepository().joinPublicMatch"),
                ("DatabaseService().leavePublicMatch", "MatchRepository().leavePublicMatch"),
                ("DatabaseService().generateFixtures", "TournamentRepository().generateFixtures"),
                ("DatabaseService().updateTournamentMatchScore", "TournamentRepository().updateTournamentMatchScore"),
                ("print(", "// print(") 
            ])

if __name__ == "__main__":
    main()
