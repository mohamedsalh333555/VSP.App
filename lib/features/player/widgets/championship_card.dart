import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_countdown_timer.dart';
import '../screens/championship_details_screen.dart';

class ChampionshipCard extends StatelessWidget {
  final Championship championship;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const ChampionshipCard({super.key, required this.championship, this.width, this.margin});

  @override
  Widget build(BuildContext context) {
    final int remainingTeams =
        (championship.maxTeams - championship.joinedTeams.length).clamp(0, championship.maxTeams);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChampionshipDetailsScreen(championship: championship),
        ),
      ),
      child: Container(
        width: width ?? (MediaQuery.sizeOf(context).width - 32).clamp(250.0, 320.0),
        padding: const EdgeInsets.all(16),
        margin: margin ?? EdgeInsets.zero,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypeBadge(AppLocalizations.of(context)!.tournament),
                    if (championship.governorate.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                          border: Border.all(color: VSPColors.divider, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              championship.governorate,
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Builder(builder: (context) {
                  final isFull = championship.isFull || championship.joinedTeams.length >= championship.maxTeams;
                  final isCompleted = championship.status == 'completed';
                  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

                  String badgeText;
                  Color badgeColor;

                  if (isCompleted) {
                    badgeText = isArabic ? 'مكتملة' : 'COMPLETED';
                    badgeColor = VSPColors.accent;
                  } else if (isFull) {
                    badgeText = AppLocalizations.of(context)!.full.toUpperCase();
                    badgeColor = VSPColors.warning;
                  } else {
                    badgeText = AppLocalizations.of(context)!.open.toUpperCase();
                    badgeColor = VSPColors.accent;
                  }

                  return _buildStatusBadge(badgeText, badgeColor);
                }),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: VSPColors.iconBadgeBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(championship.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(championship.type,
                          style: const TextStyle(
                              color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Iconsax.share_copy, color: VSPColors.textSecondary, size: 18),
                  onPressed: () =>
                      SharingService.shareChampionshipObject(context: context, championship: championship),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Builder(builder: (context) {
                    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                    final dateStr =
                        AppDateFormatter.formatDayMonth(championship.startDate, isArabic ? 'ar' : 'en');
                    return _buildCompactInfo(Iconsax.calendar_1_copy, isArabic ? 'البداية' : 'START', dateStr);
                  }),
                  _buildDivider(),
                  Builder(builder: (context) {
                    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                    return _buildCompactInfo(
                        Iconsax.cup_copy,
                        isArabic ? 'الجائزة' : 'PRIZE',
                        championship.grandPrize > 0
                            ? "${championship.grandPrize.toInt()} ${AppLocalizations.of(context)!.egCurrency}"
                            : (isArabic ? "كأس وميداليات" : "Cup & Medals"));
                  }),
                  _buildDivider(),
                  Builder(builder: (context) {
                    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                    return _buildCompactInfo(Iconsax.card_copy, isArabic ? 'الاشتراك' : 'FEE',
                        "${championship.entryFee.toInt()} ${AppLocalizations.of(context)!.egCurrency}");
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Builder(builder: (context) {
                    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                    final isCompleted = championship.status == 'completed';
                    final isFull =
                        championship.isFull || championship.joinedTeams.length >= championship.maxTeams;

                    if (isCompleted) {
                      final hasWinner =
                          championship.championTeamName != null && championship.championTeamName!.isNotEmpty;
                      return Row(
                        children: [
                          const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hasWinner
                                  ? (isArabic
                                      ? 'البطل: ${championship.championTeamName}'
                                      : 'Champion: ${championship.championTeamName}')
                                  : (isArabic ? 'البطولة مكتملة ' : 'Tournament Completed '),
                              style: const TextStyle(
                                  color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    } else if (isFull) {
                      return Text(
                        isArabic ? 'البطولة مكتملة العدد ' : 'Tournament Full ',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "$remainingTeams",
                                style: const TextStyle(
                                  color: VSPColors.accent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)!.spotsLeft,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: VSPColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          if (championship.status == 'open' && championship.startDate.isAfter(DateTime.now())) ...[
                            const SizedBox(height: 4),
                            VSPCountdownTimer(targetDate: championship.startDate, isCompact: true),
                          ],
                        ],
                      );
                    }
                  }),
                ),
                const SizedBox(width: 8),
                Builder(builder: (context) {
                  final isFull =
                      championship.isFull || championship.joinedTeams.length >= championship.maxTeams;
                  final isCompleted = championship.status == 'completed';
                  final isClosed = isFull || isCompleted;
                  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

                  return Container(
                    height: 42.0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isClosed ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.accent,
                      borderRadius: BorderRadius.circular(12),
                      border: isClosed ? Border.all(color: VSPColors.accent, width: 1.5) : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isClosed
                                ? (isArabic ? 'عرض البطولة' : 'View Tournament')
                                : AppLocalizations.of(context)!.join,
                            style: TextStyle(
                              color: isClosed ? VSPColors.accent : Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
                            size: 16,
                            color: isClosed ? VSPColors.accent : Colors.black,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String text) =>
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold));

  Widget _buildStatusBadge(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: VSPColors.iconBadgeBg,
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))
      ]));

  Widget _buildCompactInfo(IconData? icon, String headerTitle, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          headerTitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Container(width: 1, height: 22, color: Colors.white10);
}
