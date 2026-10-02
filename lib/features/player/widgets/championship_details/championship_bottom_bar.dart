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
      child: Builder(
        builder: (context) {
          final status = championship.status.trim().toLowerCase();

          if (isTeamRegistered && myTeam != null) {
            return PrimaryButton(
              text: isArabic ? 'إدارة تشكيلة الفريق' : 'Manage team roster',
              color: VSPColors.accent,
              textColor: Colors.black,
              onPressed: onManageRoster,
            );
          }

          if (status == 'cancelled') {
            return PrimaryButton(
              text: isArabic ? 'البطولة ملغاة' : 'Championship cancelled',
              onPressed: null,
              color: VSPColors.surfaceAlt,
              textColor: VSPColors.textMuted,
            );
          }

          if (status == 'ongoing' || status == 'completed' || isFull || status == 'full') {
            return PrimaryButton(
              text: status == 'completed'
                  ? (isArabic ? 'عرض البطولة' : 'View championship')
                  : (isArabic ? 'عرض المباريات والجدول' : 'View matches & standings'),
              onPressed: onViewBrackets,
            );
          }

          if (status != 'open') {
            return PrimaryButton(
              text: isArabic ? 'التسجيل مغلق' : 'Registration closed',
              onPressed: null,
              color: VSPColors.surfaceAlt,
              textColor: VSPColors.textMuted,
            );
          }

          return PrimaryButton(
            text: isArabic ? 'سجّل فريقك الآن' : 'Register your team',
            isLoading: isJoining,
            onPressed: isJoining ? null : onJoin,
          );
        },
      ),
    );
  }
}
