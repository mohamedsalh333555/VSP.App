import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

class TeamProfileActionBar extends StatelessWidget {
  final Team team;
  final bool isCaptain;
  final bool isGeneratingCode;
  final VoidCallback onGenerateCode;
  final VoidCallback onChallengeTeam;

  const TeamProfileActionBar({
    super.key,
    required this.team,
    required this.isCaptain,
    required this.isGeneratingCode,
    required this.onGenerateCode,
    required this.onChallengeTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (isCaptain) {
      return OutlinedButton.icon(
        onPressed: isGeneratingCode ? null : onGenerateCode,
        icon: isGeneratingCode
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
              )
            : const Icon(Iconsax.key_copy, color: VSPColors.accent),
        label: Text(
          isArabic ? 'توليد كود مواجهة جديد (صالحة لساعة)' : 'Generate Matchup Invite Code',
          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: VSPColors.accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
        ),
      );
    }

    if (team.captainPhone != null && team.captainPhone!.isNotEmpty) {
      return PrimaryButton(
        text: isArabic ? 'تحدي هذا الفريق ' : 'Challenge Team ',
        onPressed: onChallengeTeam,
      );
    }

    return const SizedBox.shrink();
  }
}
