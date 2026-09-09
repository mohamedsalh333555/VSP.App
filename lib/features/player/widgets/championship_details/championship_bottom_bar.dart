import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Floating bottom action bar handling tournament registration, bracket viewing, and roster management.
class ChampionshipBottomBar extends StatelessWidget {
  final Championship championship;
  final Team? myTeam;
  final bool isTeamRegistered;
  final bool isFull;
  final bool isJoining;
  final VoidCallback onManageRoster;
  final VoidCallback onViewBrackets;
  final VoidCallback onJoin;

  const ChampionshipBottomBar({
    super.key,
    required this.championship,
    required this.myTeam,
    required this.isTeamRegistered,
    required this.isFull,
    required this.isJoining,
    required this.onManageRoster,
    required this.onViewBrackets,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        VSPSpacing.md,
        VSPSpacing.sm,
        VSPSpacing.md,
        MediaQuery.of(context).padding.bottom + VSPSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
      ),
      child: (isTeamRegistered && myTeam != null)
          ? PrimaryButton(
              text: isArabic
                  ? 'فريقك مسجّل بالبطولة | إدارة التشكيلة '
                  : 'Team Registered | Manage Roster ',
              color: VSPColors.accent,
              textColor: Colors.black,
              onPressed: onManageRoster,
            )
          : (isFull ||
                  championship.status == 'ongoing' ||
                  championship.status == 'completed')
              ? PrimaryButton(
                  text: isFull &&
                          championship.status != 'ongoing' &&
                          championship.status != 'completed'
                      ? (isArabic
                          ? 'مكتمل العدد (مشاهدة القرعة والجدول)'
                          : 'Fully Booked (View Brackets)')
                      : l10n.viewBrackets,
                  onPressed: onViewBrackets,
                )
              : PrimaryButton(
                  text: isArabic ? 'انضمام للبطولة الآن ' : l10n.join,
                  isLoading: isJoining,
                  onPressed: isJoining ? null : onJoin,
                ),
    );
  }
}
