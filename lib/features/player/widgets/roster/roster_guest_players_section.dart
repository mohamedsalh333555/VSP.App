import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/custom_text_field.dart';

/// Section managing offline guest players without registered VSP accounts,
/// including WhatsApp squad parsing and manual addition.
class RosterGuestPlayersSection extends StatelessWidget {
  final List<String> guestNames;
  final TextEditingController guestController;
  final bool canEdit;
  final bool isArabic;
  final VoidCallback onAddGuest;
  final ValueChanged<int> onRemoveGuest;
  final VoidCallback onPasteFromWhatsApp;

  const RosterGuestPlayersSection({
    super.key,
    required this.guestNames,
    required this.guestController,
    required this.canEdit,
    required this.isArabic,
    required this.onAddGuest,
    required this.onRemoveGuest,
    required this.onPasteFromWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'لاعبون ضيوف (بدون حساب)' : 'Guest Players (No App Account)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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

        if (canEdit) ...[
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: guestController,
                  hintText: isArabic ? 'اسم اللاعب الضيف (مثال: أحمد مصطفى)' : 'Guest player name',
                  maxLength: 30,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAddGuest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.input),
                  ),
                ),
                child: Text(
                  isArabic ? 'إضافة' : 'Add',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        if (guestNames.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
            ),
            child: Text(
              isArabic ? 'لم يتم إضافة لاعبين ضيوف حتى الآن.' : 'No guest players added yet.',
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: guestNames.length,
            itemBuilder: (context, index) {
              final name = guestNames[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.user_copy, color: VSPColors.accent, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isArabic ? 'ضيف' : 'Guest',
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (canEdit)
                      IconButton(
                        icon: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 18),
                        onPressed: () => onRemoveGuest(index),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
