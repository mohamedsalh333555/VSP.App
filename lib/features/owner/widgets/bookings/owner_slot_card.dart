import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/services/vsp_time_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Card rendering individual slot states: Available, Break, Expired, or Booked (Manual/Player).
class OwnerSlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;

  const OwnerSlotCard({
    super.key,
    required this.slot,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final now = VSPTimeService.now;
    final DateTime? slotTime = slot['slotTime'] as DateTime?;

    // Slot is past if more than 15 minutes have passed since its start time
    final bool isPast = slotTime != null && now.isAfter(slotTime.add(const Duration(minutes: 15)));
    // Slot is "NOW" if current time is within 15 minutes before or after its start time
    final bool isNowSlot = !isPast &&
        slotTime != null &&
        now.isAfter(slotTime.subtract(const Duration(minutes: 15))) &&
        now.isBefore(slotTime.add(const Duration(minutes: 15)));

    if (slot['type'] == 'empty' || slot['type'] == 'break') {
      final bool isBreak = slot['type'] == 'break';
      final Color badgeColor = isBreak
          ? VSPColors.textSecondary
          : (isNowSlot
              ? VSPColors.accent
              : (isPast ? VSPColors.textSecondary.withValues(alpha: 0.35) : VSPColors.accent));

      final String badgeText = isBreak
          ? l10n.closedBadge
          : (isNowSlot ? (isAr ? 'الآن' : 'NOW') : (isPast ? (isAr ? 'منقضي' : 'Expired') : l10n.openBadge));

      return Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isNowSlot ? VSPColors.accent.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isNowSlot
                ? VSPColors.accent.withValues(alpha: 0.5)
                : (isPast ? VSPColors.divider.withValues(alpha: 0.2) : VSPColors.divider),
            width: isNowSlot ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isBreak ? Iconsax.close_circle_copy : (isPast ? Iconsax.clock_copy : Iconsax.add_circle_copy),
              color: isPast
                  ? VSPColors.textSecondary.withValues(alpha: 0.35)
                  : (isNowSlot ? VSPColors.accent : VSPColors.textSecondary),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              isBreak
                  ? l10n.breakTime
                  : (isPast ? (isAr ? 'موعد منقضي' : 'Expired Slot') : (isAr ? 'متاح للحجز' : 'Available')),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isPast ? VSPColors.textSecondary.withValues(alpha: 0.35) : VSPColors.textSecondary,
                    fontWeight: isNowSlot ? FontWeight.bold : FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isPast ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                border: isNowSlot ? Border.all(color: VSPColors.accent.withValues(alpha: 0.4)) : null,
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final booking = slot['booking'] as Booking?;
    final bool isMerged = slot['merged'] == true;
    final bool isManual = slot['type'] == 'manual';
    final bool isCompleted = booking != null && booking.endTime.isBefore(now);
    final String? durationLabel = slot['durationLabel'] as String?;

    return Container(
      height: isMerged ? null : 70,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMerged ? 14 : 0),
      decoration: BoxDecoration(
        color: isManual ? VSPColors.surface : VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: isManual ? VSPColors.accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot['name'] ?? '',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: VSPColors.textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (durationLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          durationLabel,
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if ((slot['subtitle'] as String?)?.isNotEmpty ?? false) ...[
                      Flexible(
                        child: Text(
                          slot['subtitle'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: VSPColors.textSecondary,
                                fontSize: 10.5,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Builder(builder: (context) {
                      final String paymentStatus = booking?.paymentStatus ?? 'pending';
                      final double depositPaid = booking?.depositPaid ?? 0.0;
                      final double totalPrice = booking?.totalPrice ?? 0.0;
                      final bool isPaidInFull = (booking?.isPaid ?? false) ||
                          paymentStatus == 'paid' ||
                          (totalPrice > 0 && depositPaid >= totalPrice);
                      final bool isPartiallyPaid = !isPaidInFull &&
                          (paymentStatus == 'partially_paid' ||
                              (booking?.isDepositPaid ?? false) ||
                              depositPaid > 0);

                      final double remaining = totalPrice - depositPaid;
                      final String badgeLabel;
                      final Color badgeColor;
                      if (isPaidInFull) {
                        badgeLabel = isAr ? 'مدفوع بالكامل' : 'Paid in Full';
                        badgeColor = VSPColors.success;
                      } else if (isCompleted) {
                        badgeLabel = isAr ? 'محصل' : 'Collected';
                        badgeColor = VSPColors.success;
                      } else if (isPartiallyPaid) {
                        badgeLabel = isAr
                            ? 'متبقي ${remaining.toStringAsFixed(0)} ج.م'
                            : 'Rem. ${remaining.toStringAsFixed(0)} EGP';
                        badgeColor = VSPColors.info;
                      } else {
                        badgeLabel = isAr ? 'كاش عند الحضور' : 'Pay on Arrival';
                        badgeColor = Colors.white60;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(VSPRadius.xs),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          Builder(builder: (context) {
            final double rawPrice = booking?.totalPrice ?? 0.0;
            final double rawDeposit = booking?.depositPaid ?? 0.0;
            final double cardPrice = rawPrice > 0 ? rawPrice : (rawDeposit > 0 ? rawDeposit : 0.0);

            if (cardPrice <= 0) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${cardPrice.toInt()} ${isAr ? "ج.م" : "EGP"}',
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            );
          }),
          const Icon(Iconsax.arrow_right_1_copy, color: VSPColors.textSecondary, size: 14),
        ],
      ),
    );
  }
}
