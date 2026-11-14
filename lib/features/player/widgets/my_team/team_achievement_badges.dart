import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'team_achievement_summary.dart';

/// Compact, localized team achievements for the profile team card.
/// Values must come from verified competition results, not user-entered counts.
class TeamAchievementBadges extends StatelessWidget {
  final TeamAchievementSummary summary;

  const TeamAchievementBadges({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Semantics(
      label: isArabic
          ? '${summary.stadiumChampionships} بطولات ملاعب رسمية، ${summary.oneVsOneChampionPlayers} أبطال واحد ضد واحد'
          : '${summary.stadiumChampionships} verified stadium championships, ${summary.oneVsOneChampionPlayers} one versus one champion players',
      child: ExcludeSemantics(
        child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _badge(
            context,
            maxWidth: constraints.maxWidth,
            icon: Iconsax.cup_copy,
            count: summary.stadiumChampionships,
            label: isArabic ? 'بطولات الملاعب' : 'Stadium titles',
          ),
          _badge(
            context,
            maxWidth: constraints.maxWidth,
            icon: Iconsax.medal_copy,
            count: summary.oneVsOneChampionPlayers,
            label: isArabic ? 'أبطال 1 ضد 1' : '1v1 champions',
            suffix: '×',
          ),
        ],
        ),
        ),
      ),
    );
  }

  Widget _badge(
    BuildContext context, {
    required double maxWidth,
    required IconData icon,
    required int count,
    required String label,
    String suffix = '',
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth.isFinite ? maxWidth : 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: VSPColors.accent),
          const SizedBox(width: 6),
          Text('$count$suffix', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              // Full titles must remain available with large accessibility text.
              softWrap: true,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
