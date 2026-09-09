import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../screens/tournament_brackets_screen.dart';

/// Bottom action bar for Owner Tournament Dashboard.
class TournamentDashboardBottomBar extends StatelessWidget {
  final Championship championship;
  final bool isLoading;
  final VoidCallback onStartTournament;

  const TournamentDashboardBottomBar({
    super.key,
    required this.championship,
    required this.isLoading,
    required this.onStartTournament,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        VSPSpacing.md,
        VSPSpacing.md,
        VSPSpacing.md,
        VSPSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (championship.status == 'open')
            PrimaryButton(
              text: l10n.generateDrawStart,
              isLoading: isLoading,
              onPressed: onStartTournament,
            ),
          if (championship.status != 'open')
            PrimaryButton(
              text: l10n.viewBrackets.toUpperCase(),
              color: VSPColors.accent.withValues(alpha: 0.1),
              textColor: VSPColors.accent,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TournamentBracketsScreen(
                      championship: championship,
                      isOwner: true,
                    ),
                  ),
                );
              },
            ),
          if (championship.status == 'completed' || championship.championTeamName != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isAr
                        ? 'بطل البطولة: ${championship.championTeamName ?? ""}'
                        : 'Champion: ${championship.championTeamName ?? ""}',
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
