import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/custom_text_field.dart';

/// Form section managing offline tournament roster entries (5 to 12 players).
class TournamentManualTeamRosterSection extends StatelessWidget {
  final TextEditingController playerInputCtrl;
  final List<String> offlinePlayerNames;
  final VoidCallback onAddPlayer;
  final ValueChanged<String> onRemovePlayer;
  final VoidCallback onChanged;

  const TournamentManualTeamRosterSection({
    super.key,
    required this.playerInputCtrl,
    required this.offlinePlayerNames,
    required this.onAddPlayer,
    required this.onRemovePlayer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final totalPlayers = offlinePlayerNames.length;
    final isValidRoster = totalPlayers >= 5 && totalPlayers <= 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'كشف أسماء اللاعبين (من 5 إلى 12):' : 'Roster (5 to 12 players):',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$totalPlayers / 12',
                style: TextStyle(
                  color: isValidRoster ? VSPColors.accent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: playerInputCtrl,
                hintText: isArabic
                    ? 'اكتب اسم اللاعب واضغط إضافة...'
                    : 'Enter player name...',
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: onAddPlayer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                ),
                child: const Icon(Iconsax.add_copy, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (offlinePlayerNames.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VSPColors.background,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: offlinePlayerNames.map((name) {
                return Chip(
                  backgroundColor: VSPColors.surfaceAlt,
                  label: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  deleteIcon: const Icon(Iconsax.close_circle_copy, size: 14, color: VSPColors.error),
                  onDeleted: () => onRemovePlayer(name),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    side: const BorderSide(color: VSPColors.divider),
                  ),
                );
              }).toList(),
            ),
          ),
        if (totalPlayers < 5) ...[
          const SizedBox(height: 8),
          Text(
            isArabic
                ? ' يجب إضافة ${5 - totalPlayers} لاعبين إضافيين لتشغيل كشف الفريق'
                : ' Add ${5 - totalPlayers} more players',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
