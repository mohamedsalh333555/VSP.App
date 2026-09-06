import os

# 1. Patch owner_tournament_dashboard_screen.dart
owner_screen_path = r'k:\.gemini\antigravity\scratch\vsp_application\lib\features\owner\screens\owner_tournament_dashboard_screen.dart'
with open(owner_screen_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'text: l10n.proceedAnyway,' in line:
        # Check if the surrounding block can be guarded
        # Look backwards for the PrimaryButton(text: l10n.proceedAnyway)
        for j in range(max(0, i - 15), i + 10):
            if 'l10n.unpaidTeamsWarning(unpaidNames),' in lines[j]:
                lines[j] = "                  _currentChampionship.entryFee > 0 ? (Localizations.localeOf(context).languageCode == 'ar' ? 'لا يمكن إطلاق القرعة في بطولة مدفوعة بوجود فرق لم تسدد بعد: ' + unpaidNames + '. يرجى انتظار السداد أو استبعاد الفرق غير المسددة لضمان العدالة.' : 'Cannot start a paid tournament with unpaid teams: ' + unpaidNames) : l10n.unpaidTeamsWarning(unpaidNames),\n"
        
        # Hide the proceed button if entryFee > 0
        lines[i] = "                        text: _currentChampionship.entryFee > 0 ? (Localizations.localeOf(context).languageCode == 'ar' ? 'فهمت ذلك' : 'Understood') : l10n.proceedAnyway,\n"
        for k in range(i, i + 5):
            if 'onPressed: () => Navigator.pop(ctx, true),' in lines[k]:
                lines[k] = "                        onPressed: () => Navigator.pop(ctx, _currentChampionship.entryFee <= 0),\n"
                break
        break

with open(owner_screen_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print("✅ owner_tournament_dashboard_screen.dart patched: unpaid teams blocked for paid tournaments.")


# 2. Patch championship_details_screen.dart
details_path = r'k:\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\championship_details_screen.dart'
with open(details_path, 'r', encoding='utf-8') as f:
    d_content = f.read()

target_d = "value: '${championship.grandPrize.toInt()} ${isArabic ? \"ج.م\" : \"EGP\"}',"
replacement_d = "value: championship.grandPrize > 0 ? '${championship.grandPrize.toInt()} ${isArabic ? \"ج.م\" : \"EGP\"}' : (isArabic ? 'كأس وميداليات' : 'Cup & Medals'),"

if target_d in d_content:
    d_content = d_content.replace(target_d, replacement_d, 1)
    with open(details_path, 'w', encoding='utf-8') as f:
        f.write(d_content)
    print("✅ championship_details_screen.dart grandPrize display patched!")
else:
    print("ℹ️ championship_details_screen.dart already updated or target not found.")


# 3. Patch player_home_screen.dart
home_path = r'k:\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\player_home_screen.dart'
with open(home_path, 'r', encoding='utf-8') as f:
    h_content = f.read()

target_h = 'return _buildCompactInfo(Iconsax.cup_copy, isArabic ? \'الجائزة\' : \'PRIZE\', "${championship.grandPrize.toInt()} ${AppLocalizations.of(context)!.egCurrency}");'
replacement_h = 'return _buildCompactInfo(Iconsax.cup_copy, isArabic ? \'الجائزة\' : \'PRIZE\', championship.grandPrize > 0 ? "${championship.grandPrize.toInt()} ${AppLocalizations.of(context)!.egCurrency}" : (isArabic ? "كأس وميداليات" : "Cup & Medals"));'

if target_h in h_content:
    h_content = h_content.replace(target_h, replacement_h, 1)
    with open(home_path, 'w', encoding='utf-8') as f:
        f.write(h_content)
    print("✅ player_home_screen.dart grandPrize display patched!")
else:
    print("ℹ️ player_home_screen.dart already updated or target not found.")


# 4. Patch owner_cup_screen.dart
owner_cup_path = r'k:\.gemini\antigravity\scratch\vsp_application\lib\features\owner\screens\owner_cup_screen.dart'
with open(owner_cup_path, 'r', encoding='utf-8') as f:
    oc_content = f.read()

target_oc = "_buildInfoColumn(isArabic ? 'الجائزة الكبرى' : 'GRAND PRIZE', '${tournament.grandPrize.toInt()} ${isArabic ? \"ج.م\" : \"EGP\"}'),"
replacement_oc = "_buildInfoColumn(isArabic ? 'الجائزة الكبرى' : 'GRAND PRIZE', tournament.grandPrize > 0 ? '${tournament.grandPrize.toInt()} ${isArabic ? \"ج.م\" : \"EGP\"}' : (isArabic ? 'كأس وميداليات' : 'Cup & Medals')),"

if target_oc in oc_content:
    oc_content = oc_content.replace(target_oc, replacement_oc, 1)
    with open(owner_cup_path, 'w', encoding='utf-8') as f:
        f.write(oc_content)
    print("✅ owner_cup_screen.dart grandPrize display patched!")
else:
    print("ℹ️ owner_cup_screen.dart already updated or target not found.")
