import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../shared/widgets/primary_button.dart';

Future<void> showTeamMatchupInviteModal(BuildContext context, String code) async {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VSPColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),
          const Icon(Iconsax.key_copy, color: VSPColors.accent, size: 40),
          const SizedBox(height: VSPSpacing.md),
          const Text(
            'كود دعوة المواجهة الجديد',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'شارك هذا الكود مع كابتن الفريق المنافس لإضافتكم في مواجهة (صالح لمدة ساعة واحدة)',
            style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VSPSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.accent, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Iconsax.copy_copy, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    VSPFeedback.showSuccess(ctx, 'تم نسخ كود المواجهة! ');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.xl),
          PrimaryButton(
            text: 'تم',
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: VSPSpacing.md),
        ],
      ),
    ),
  );
}
