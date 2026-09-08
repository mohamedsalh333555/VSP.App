import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/components/vsp_card.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
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

    return VSPCard(
      margin: const EdgeInsets.all(VSPSpacing.md),
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                l10n.statusLabel,
                championship.status.toUpperCase(),
                color: championship.status == 'completed' ? VSPColors.error : VSPColors.accent,
              ),
              _buildInfoItem(context, l10n.categoryLabel, championship.type),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                l10n.datesLabel,
                '${DateFormat('MMM d').format(championship.startDate)} - ${DateFormat('MMM d').format(championship.endDate)}',
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
                  color: championship.prizeDelivered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
            ],
          ),
          if (championship.status == 'completed' && !championship.prizeDelivered) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
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
