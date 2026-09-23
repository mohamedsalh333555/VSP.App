import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import 'booking_slot_models.dart';

/// بطاقة تمثيل شريحة زمنية مفردة مع كافة حالاتها البصرية والتفاعلية
class BookingSlotCard extends StatelessWidget {
  final TimeSlotItem slotItem;
  final bool isBooked;
  final bool isPast;
  final bool isSelected;
  final bool isCurrentOngoing;
  final bool isNextAvailable;
  final bool isFirstOvernightSlot;
  final String nextDayName;
  final VoidCallback onTap;

  const BookingSlotCard({
    super.key,
    required this.slotItem,
    required this.isBooked,
    required this.isPast,
    required this.isSelected,
    required this.isCurrentOngoing,
    required this.isNextAvailable,
    required this.isFirstOvernightSlot,
    required this.nextDayName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final slotWidget = GestureDetector(
      onTap: (isBooked || isPast) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
        padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md, horizontal: VSPSpacing.lg),
        decoration: BoxDecoration(
          color: isBooked
              ? VSPColors.error.withValues(alpha: 0.08)
              : (isPast
                  ? VSPColors.surface.withValues(alpha: 0.3)
                  : (isSelected ? VSPColors.accent.withValues(alpha: 0.18) : Colors.transparent)),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isBooked
                ? VSPColors.error.withValues(alpha: 0.3)
                : (isPast
                    ? Colors.transparent
                    : (isSelected
                        ? VSPColors.accent
                        : (isNextAvailable ? VSPColors.accent.withValues(alpha: 0.5) : VSPColors.divider))),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              const Icon(Iconsax.tick_circle_copy, size: 18, color: VSPColors.accent),
              const SizedBox(width: 8),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slotItem.startTime,
                  style: TextStyle(
                    color: isBooked
                        ? VSPColors.error.withValues(alpha: 0.7)
                        : (isPast
                            ? VSPColors.textSecondary.withValues(alpha: 0.4)
                            : (isSelected ? VSPColors.textPrimary : VSPColors.textPrimary)),
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    decoration: (isBooked || isPast) ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '–',
                    style: TextStyle(
                      color: isBooked
                          ? VSPColors.error.withValues(alpha: 0.7)
                          : (isSelected ? VSPColors.accent : VSPColors.textSecondary),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  slotItem.endTime,
                  style: TextStyle(
                    color: isBooked
                        ? VSPColors.error.withValues(alpha: 0.7)
                        : (isPast
                            ? VSPColors.textSecondary.withValues(alpha: 0.4)
                            : (isSelected ? VSPColors.textPrimary : VSPColors.textPrimary)),
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    decoration: (isBooked || isPast) ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
              ],
            ),
            if (isBooked) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: VSPColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                  border: Border.all(color: VSPColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.lock_copy, size: 12, color: VSPColors.error),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? ' محجوز' : ' Booked',
                      style: const TextStyle(color: VSPColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else if (isCurrentOngoing) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                  border: Border.all(color: VSPColors.warning),
                ),
                child: Text(
                  isArabic ? ' الآن' : ' NOW',
                  style: const TextStyle(color: VSPColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ] else if (isNextAvailable) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  isArabic ? ' الأقرب' : ' Next Available',
                  style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ] else if (isPast) ...[
              const SizedBox(width: 12),
              Text(
                isArabic ? 'منقضي' : 'Past',
                style: TextStyle(
                  color: VSPColors.textSecondary.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isFirstOvernightSlot) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10, right: 4, left: 4),
            child: Text(
              isArabic ? 'بعد منتصف الليل ($nextDayName)' : 'After Midnight ($nextDayName)',
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          slotWidget,
        ],
      );
    }

    return slotWidget;
  }
}
