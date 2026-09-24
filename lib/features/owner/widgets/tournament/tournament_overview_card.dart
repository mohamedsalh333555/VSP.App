import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/components/vsp_card.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Overview card showing tournament status, category, dates, capacity and prize pool.
class TournamentOverviewCard extends StatelessWidget {
  final Championship championship;
  final VoidCallback onRecordPrizeDelivery;

  const TournamentOverviewCard({
    super.key,
    required this.championship,
    required this.onRecordPrizeDelivery,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;

    final String statusText;
    final Color statusColor;
    if (!championship.isApproved) {
      statusText = isArabic ? 'قيد المراجعة' : 'Pending Review';
      statusColor = VSPColors.warning;
    } else {
      switch (championship.status.toLowerCase()) {
        case 'open':
          statusText = isArabic ? 'مفتوحة للتسجيل' : 'Open';
          statusColor = VSPColors.accent;
          break;
        case 'ongoing':
          statusText = isArabic ? 'جارية' : 'Ongoing';
          statusColor = VSPColors.success;
          break;
        case 'completed':
        case 'finished':
          statusText = isArabic ? 'مكتملة' : 'Completed';
          statusColor = VSPColors.textSecondary;
          break;
        case 'cancelled':
          statusText = isArabic ? 'ملغاة' : 'Cancelled';
          statusColor = VSPColors.error;
          break;
        default:
          statusText = championship.status.toUpperCase();
          statusColor = VSPColors.accent;
      }
    }

    final String categoryText;
    switch (championship.type) {
      case 'Cup':
        categoryText = isArabic ? 'خروج المغلوب (كأس)' : 'Knockout';
        break;
      case 'League':
        categoryText = isArabic ? 'دوري نقاط' : 'League';
        break;
      case 'GroupsAndKnockout':
        categoryText = isArabic ? 'مجموعات وتصفيات' : 'Groups & Knockout';
        break;
      default:
        categoryText = championship.type;
    }

    final dateRange = '${AppDateFormatter.formatDayMonth(championship.startDate, isArabic ? 'ar' : 'en')} - ${AppDateFormatter.formatDayMonth(championship.endDate, isArabic ? 'ar' : 'en')}';

    return VSPCard(
      margin: const EdgeInsets.all(VSPSpacing.md),
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        children: [
          if (!championship.isApproved) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle_copy, color: VSPColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'البطولة بانتظار موافقة الإدارة، وستظهر للفرق واللاعبين فور اعتمادها.'
                          : 'Tournament is pending admin approval and will appear to players once approved.',
                      style: const TextStyle(
                        color: VSPColors.warning,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                l10n.statusLabel,
                statusText,
                color: statusColor,
              ),
              _buildInfoItem(context, l10n.categoryLabel, categoryText),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                l10n.datesLabel,
                dateRange,
              ),
              _buildInfoItem(
                context,
                l10n.teamsLabel,
                '${championship.joinedTeams.length} / ${championship.maxTeams}',
                isLtr: true,
              ),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                isArabic ? 'وعاء الجوائز الفعلي' : 'Actual Prize Pool',
                championship.prizePool > 0
                    ? '${championship.prizePool.toInt()} ${isArabic ? "ج.م" : "EGP"}'
                    : (championship.grandPrize > 0
                        ? '${championship.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}'
                        : (isArabic ? 'كأس وميداليات' : 'Cup & Medals')),
                color: VSPColors.accent,
              ),
              if (championship.status == 'completed')
                _buildInfoItem(
                  context,
                  isArabic ? 'حالة التسليم' : 'Delivery Status',
                  championship.prizeDelivered
                      ? (isArabic ? 'تم التسليم' : 'Delivered')
                      : (isArabic ? 'بانتظار التسليم' : 'Pending'),
                  color: championship.prizeDelivered ? VSPColors.success : VSPColors.warning,
                ),
            ],
          ),
          if (championship.status == 'completed' && !championship.prizeDelivered) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.success.withValues(alpha: 0.15),
                  foregroundColor: VSPColors.success,
                  side: const BorderSide(color: VSPColors.success),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                ),
                icon: const Icon(Iconsax.award_copy, size: 16),
                label: Text(
                  isArabic ? 'توثيق تسليم الجائزة للبطل' : 'Record Prize Delivery',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: onRecordPrizeDelivery,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, {Color? color, bool isLtr = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 4),
        isLtr
            ? Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color ?? VSPColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              )
            : Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color ?? VSPColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
      ],
    );
  }
}
