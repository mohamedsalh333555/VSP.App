path = 'lib/features/owner/screens/owner_tournament_dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """ const Divider(color: VSPColors.divider, height: 32),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _buildInfoItem(
 AppLocalizations.of(context)!.datesLabel, 
 '${DateFormat('MMM d').format(currentChamp.startDate)} - ${DateFormat('MMM d').format(currentChamp.endDate)}',
 ),
 _buildInfoItem(
 AppLocalizations.of(context)!.teamsLabel, 
 '${currentChamp.joinedTeams.length} / ${currentChamp.maxTeams}',
 isLtr: true,
 ),
 ],
 ),
 ],"""

replacement = """ const Divider(color: VSPColors.divider, height: 24),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _buildInfoItem(
 AppLocalizations.of(context)!.datesLabel, 
 '${DateFormat('MMM d').format(currentChamp.startDate)} - ${DateFormat('MMM d').format(currentChamp.endDate)}',
 ),
 _buildInfoItem(
 AppLocalizations.of(context)!.teamsLabel, 
 '${currentChamp.joinedTeams.length} / ${currentChamp.maxTeams}',
 isLtr: true,
 ),
 ],
 ),
 const Divider(color: VSPColors.divider, height: 24),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _buildInfoItem(
 Localizations.localeOf(context).languageCode == 'ar' ? 'وعاء الجوائز الفعلي' : 'Actual Prize Pool',
 currentChamp.prizePool > 0
 ? '${currentChamp.prizePool.toInt()} ${Localizations.localeOf(context).languageCode == 'ar' ? "ج.م" : "EGP"}'
 : (currentChamp.grandPrize > 0
 ? '${currentChamp.grandPrize.toInt()} ${Localizations.localeOf(context).languageCode == 'ar' ? "ج.م" : "EGP"}'
 : (Localizations.localeOf(context).languageCode == 'ar' ? 'كأس وميداليات' : 'Cup & Medals')),
 color: VSPColors.accent,
 ),
 if (currentChamp.status == 'completed')
 _buildInfoItem(
 Localizations.localeOf(context).languageCode == 'ar' ? 'حالة التسليم' : 'Delivery Status',
 currentChamp.prizeDelivered
 ? (Localizations.localeOf(context).languageCode == 'ar' ? 'تم التسليم' : 'Delivered')
 : (Localizations.localeOf(context).languageCode == 'ar' ? 'بانتظار التسليم' : 'Pending'),
 color: currentChamp.prizeDelivered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
 ),
 ],
 ),
 if (currentChamp.status == 'completed' && !currentChamp.prizeDelivered) ...[
 const SizedBox(height: 12),
 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
 foregroundColor: const Color(0xFF10B981),
 side: const BorderSide(color: Color(0xFF10B981)),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 icon: const Icon(Iconsax.award_copy, size: 16),
 label: Text(
 Localizations.localeOf(context).languageCode == 'ar' ? 'توثيق تسليم الجائزة للبطل' : 'Record Prize Delivery',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
 ),
 onPressed: () => _showMarkPrizeDeliveredDialog(context, currentChamp),
 ),
 ),
 ],
 ],"""

if target in content:
    content = content.replace(target, replacement)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully replaced owner dashboard card!")
else:
    print("Target block not found.")
