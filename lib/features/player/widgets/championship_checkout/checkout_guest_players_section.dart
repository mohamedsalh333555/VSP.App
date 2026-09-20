import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class CheckoutGuestPlayersSection extends StatelessWidget {
  final TextEditingController guestController;
  final List<String> offlineGuestNames;
  final int minPlayers;
  final int totalCount;
  final VoidCallback onAddGuest;
  final VoidCallback onPasteFromWhatsApp;
  final ValueChanged<String> onRemoveGuest;

  const CheckoutGuestPlayersSection({
    super.key,
    required this.guestController,
    required this.offlineGuestNames,
    required this.minPlayers,
    required this.totalCount,
    required this.onAddGuest,
    required this.onPasteFromWhatsApp,
    required this.onRemoveGuest,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'إضافة أصدقاء من خارج التطبيق:' : 'Add External Guests:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            TextButton.icon(
              onPressed: onPasteFromWhatsApp,
              icon: const Icon(Iconsax.copy_copy, size: 16, color: VSPColors.accent),
              label: Text(
                isArabic ? 'لصق من واتساب ' : 'Paste from WhatsApp ',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: VSPSpacing.xs),
        if (totalCount < minPlayers) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'متبقي [${minPlayers - totalCount}] لاعبين لاكتمال نصاب الفريق '
                        : '[${minPlayers - totalCount}] more players needed to complete squad ',
                    style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: guestController,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => onAddGuest(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: isArabic ? 'اسم الصديق (اضغط التالي للإضافة السريعة)' : 'Guest name (press Next to add)',
                  hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: VSPColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onAddGuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                ),
              ),
              child: Text(isArabic ? 'إضافة' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (offlineGuestNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: offlineGuestNames.map((name) {
              return Chip(
                backgroundColor: VSPColors.surface,
                label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                deleteIcon: const Icon(Iconsax.close_circle_copy, size: 14, color: VSPColors.error),
                onDeleted: () => onRemoveGuest(name),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  side: const BorderSide(color: VSPColors.divider),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
