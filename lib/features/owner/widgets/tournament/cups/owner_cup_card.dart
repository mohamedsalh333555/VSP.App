import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/services/sharing_service.dart';
import '../../../../../core/ui/components/vsp_card.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../core/utils/app_date_formatter.dart';
import '../../../../../data/models.dart';
import '../../../screens/owner_tournament_dashboard_screen.dart';

class OwnerCupCard extends StatelessWidget {
  final Championship tournament;

  const OwnerCupCard({
    super.key,
    required this.tournament,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String startDateStr = AppDateFormatter.formatDayMonth(
      tournament.startDate,
      isArabic ? 'ar' : 'en',
    );
    final String endDateStr = AppDateFormatter.formatDayMonth(
      tournament.endDate,
      isArabic ? 'ar' : 'en',
    );
    final dateRange = '$startDateStr - $endDateStr';

    final String translatedSport = isArabic
        ? (tournament.sportType == 'Football' ? 'كرة القدم' : tournament.sportType)
        : tournament.sportType;
    final String translatedCategory = isArabic
        ? (tournament.type == 'Cup' ? 'كأس' : 'دوري')
        : tournament.type;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OwnerTournamentDashboardScreen(championship: tournament),
          ),
        );
      },
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: VSPCard(
        margin: const EdgeInsets.only(bottom: VSPSpacing.md),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: tournament.imageUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(tournament.imageUrl), fit: BoxFit.cover)
                        : null,
                    color: VSPColors.background,
                    border: Border.all(color: VSPColors.divider, width: 1),
                  ),
                  child: tournament.imageUrl.isEmpty
                      ? const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            '$translatedSport • $translatedCategory',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                          ),
                          _buildStatusBadge(context, tournament, isArabic),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    SharingService.shareChampionship(
                      id: tournament.id,
                      name: tournament.name,
                      startDateStr: startDateStr,
                      endDateStr: endDateStr,
                      grandPrize: tournament.grandPrize,
                      entryFee: tournament.entryFee,
                      joinedTeamsCount: tournament.joinedTeams.length,
                      maxTeams: tournament.maxTeams,
                      sportType: tournament.sportType,
                      governorate: tournament.governorate,
                      isArabic: isArabic,
                    );
                  },
                  icon: const Icon(Iconsax.share_copy, color: VSPColors.textSecondary, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: VSPColors.surfaceAlt,
                    padding: const EdgeInsets.all(10),
                    minimumSize: const Size(48, 48),
                    shape: const CircleBorder(side: BorderSide(color: VSPColors.divider, width: 0.5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(context, isArabic ? 'التاريخ' : 'DATE', dateRange),
                _buildInfoColumn(
                  context,
                  isArabic ? 'رسوم الدخول' : 'ENTRY FEE',
                  '${tournament.entryFee.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                ),
                _buildInfoColumn(
                  context,
                  isArabic ? 'الجائزة الكبرى' : 'GRAND PRIZE',
                  tournament.grandPrize > 0
                      ? '${tournament.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}'
                      : (isArabic ? 'كأس وميداليات' : 'Cup & Medals'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (tournament.joinedTeams.isNotEmpty)
                  SizedBox(
                    width: 30 + (tournament.joinedTeams.length.clamp(1, 4) - 1) * 20.0,
                    height: 30,
                    child: Stack(
                      children: List.generate(tournament.joinedTeams.length.clamp(0, 4), (i) {
                        return Positioned(
                          left: i * 18.0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VSPColors.surfaceAlt,
                              border: Border.all(color: VSPColors.surface, width: 2),
                            ),
                            child: const Icon(Iconsax.people_copy, color: VSPColors.accent, size: 14),
                          ),
                        );
                      }),
                    ),
                  ),
                if (tournament.joinedTeams.isNotEmpty) const SizedBox(width: 8),
                Text(
                  isArabic
                      ? '${tournament.joinedTeams.length} / ${tournament.maxTeams} فريق'
                      : '${tournament.joinedTeams.length} / ${tournament.maxTeams} Teams',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, Championship tourney, bool isArabic) {
    if (!tourney.isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: VSPColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: VSPColors.warning.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Text(
          isArabic ? 'قيد المراجعة' : 'Pending',
          style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }

    final status = tourney.status.toLowerCase();
    final Color badgeColor;
    final String label;

    if (status == 'ongoing') {
      badgeColor = VSPColors.accent;
      label = isArabic ? 'جارية' : 'Ongoing';
    } else if (status == 'completed' || status == 'finished') {
      badgeColor = VSPColors.textSecondary;
      label = isArabic ? 'مكتملة' : 'Completed';
    } else {
      badgeColor = VSPColors.success;
      label = isArabic ? 'مفتوحة للتسجيل' : 'Open';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
