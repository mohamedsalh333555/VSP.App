import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'booking_calendar_modal.dart';

/// شريط اختيار التاريخ للحجز (زر عرض الشهر وقائمة الأيام الـ 14 الأفقية)
class BookingDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime operationalBaseDate;
  final ValueChanged<DateTime> onDateChanged;

  const BookingDateSelector({
    super.key,
    required this.selectedDate,
    required this.operationalBaseDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: VSPColors.background,
      padding: const EdgeInsets.only(bottom: VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            child: GestureDetector(
              onTap: () => showBookingCalendarModal(
                context: context,
                initialDate: selectedDate,
                onDateSelected: onDateChanged,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.xs),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM, yyyy', Localizations.localeOf(context).toString()).format(selectedDate),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: VSPSpacing.xs),
                    const Icon(Iconsax.calendar_1_copy, color: VSPColors.textPrimary, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
          Padding(
            padding: const EdgeInsets.only(left: VSPSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.selectDate, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                const SizedBox(height: VSPSpacing.sm),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 14,
                    itemBuilder: (context, index) {
                      final date = operationalBaseDate.add(Duration(days: index));
                      final isSelected = date.day == selectedDate.day && date.month == selectedDate.month;
                      return GestureDetector(
                        onTap: () => onDateChanged(date),
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: VSPSpacing.sm),
                          decoration: BoxDecoration(
                            color: isSelected ? VSPColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                            border: Border.all(
                              color: isSelected ? VSPColors.accent : VSPColors.divider,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('E', Localizations.localeOf(context).toString()).format(date).toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? VSPColors.background : VSPColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
