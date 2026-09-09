import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Handles inter-governorate attendance commitment confirmation when a player
/// registers for a tournament outside their home governorate.
class ChampionshipGovernorateDialog {
  const ChampionshipGovernorateDialog._();

  static Future<bool> shouldConfirmAndUserConfirmed({
    required BuildContext context,
    required String championshipGovernorate,
    required String playerGovernorate,
  }) async {
    final champGovRaw = championshipGovernorate.trim();
    final playerGovRaw = playerGovernorate.trim();

    final champGovStd = EgyptGovernorates.resolveGoogleName(champGovRaw) ?? champGovRaw;
    final playerGovStd = EgyptGovernorates.resolveGoogleName(playerGovRaw) ?? playerGovRaw;

    if (champGovStd.isEmpty ||
        playerGovStd.isEmpty ||
        champGovStd.toLowerCase() == playerGovStd.toLowerCase()) {
      return true; // Same governorate or unspecified, no dialog needed
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          side: const BorderSide(color: VSPColors.divider),
        ),
        title: Row(
          children: [
            const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic ? 'تأكيد موقع البطولة' : 'Confirm Tournament Location',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هذه البطولة تُقام في ملاعب محافظة [$champGovRaw]. هل أنت وفريقك مستعدون للالتزام بالحضور وخوض المباريات في الموعد والمكان المحدد؟'
              : 'This tournament is hosted in [$champGovRaw]. Are you and your team committed to attending and playing on-site as scheduled?',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          PrimaryButton(
            text: isArabic ? 'نعم، ملتزمون بالحضور' : 'Yes, We Will Attend',
            height: 44,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    return confirmed == true;
  }
}
