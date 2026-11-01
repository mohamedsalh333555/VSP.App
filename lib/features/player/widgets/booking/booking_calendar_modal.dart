import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';

/// يعرض نافذة التقويم الشهري لاختيار موعد الحجز
void showBookingCalendarModal({
  required BuildContext context,
  required DateTime initialDate,
  required ValueChanged<DateTime> onDateSelected,
}) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    useSafeArea: true,
    barrierColor: VSPColors.background.withValues(alpha: 0.8),
    builder: (context) {
      DateTime tempSelectedDate = initialDate;
      DateTime currentMonth = DateTime(initialDate.year, initialDate.month);
      final DateTime todayMonth = DateTime(DateTime.now().year, DateTime.now().month);
      final DateTime maxMonth = DateTime(DateTime.now().year, DateTime.now().month + 3);

      return StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          final isRtl = Directionality.of(context) == TextDirection.rtl;
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          final availableHeight = mediaQuery.size.height -
              mediaQuery.viewInsets.vertical -
              (VSPSpacing.xl * 2);

          return Dialog(
            backgroundColor: VSPColors.surface,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: VSPSpacing.md,
              vertical: VSPSpacing.xl,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: availableHeight.clamp(0.0, mediaQuery.size.height).toDouble(),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(VSPSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: isArabic ? 'الشهر السابق' : 'Previous month',
                        icon: Icon(
                          isRtl ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy,
                          color: currentMonth.isAfter(todayMonth)
                              ? VSPColors.textSecondary
                              : VSPColors.textSecondary.withValues(alpha: 0.25),
                        ),
                        onPressed: currentMonth.isAfter(todayMonth)
                            ? () {
                                setModalState(() {
                                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                                });
                              }
                            : null,
                      ),
                      Text(
                        DateFormat('MMMM yyyy', Localizations.localeOf(context).toString()).format(currentMonth),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        tooltip: isArabic ? 'الشهر التالي' : 'Next month',
                        icon: Icon(
                          isRtl ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
                          color: currentMonth.isBefore(maxMonth)
                              ? VSPColors.textSecondary
                              : VSPColors.textSecondary.withValues(alpha: 0.25),
                        ),
                        onPressed: currentMonth.isBefore(maxMonth)
                            ? () {
                                setModalState(() {
                                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.calendar_1_copy, color: VSPColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${Localizations.localeOf(context).languageCode == 'ar' ? 'تاريخ الحجز: ' : 'Booking Date: '}${DateFormat('EEEE, d MMMM yyyy', Localizations.localeOf(context).toString()).format(tempSelectedDate)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    height: 240,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: DateTime(currentMonth.year, currentMonth.month + 1, 0).day +
                          (DateTime(currentMonth.year, currentMonth.month, 1).weekday - 1),
                      itemBuilder: (context, index) {
                        final firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
                        final dayOffset = index - (firstWeekday - 1);
                        if (dayOffset < 0) return const SizedBox();
                        final day = dayOffset + 1;
                        final date = DateTime(currentMonth.year, currentMonth.month, day);
                        final isSelected = date.year == tempSelectedDate.year &&
                            date.month == tempSelectedDate.month &&
                            date.day == tempSelectedDate.day;
                        final isPastDate = date.isBefore(
                          DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
                        );

                        return InkWell(
                          onTap: isPastDate
                              ? null
                              : () {
                                  setModalState(() {
                                    tempSelectedDate = date;
                                  });
                                },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? VSPColors.accent
                                  : (isPastDate ? VSPColors.surfaceAlt : Colors.transparent),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: isSelected
                                    ? VSPColors.background
                                    : (isPastDate
                                        ? VSPColors.textSecondary.withValues(alpha: 0.5)
                                        : VSPColors.textSecondary),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: l10n.cancel,
                          onPressed: () => Navigator.pop(context),
                          color: VSPColors.surfaceAlt,
                          textColor: VSPColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: VSPSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          text: l10n.apply,
                          onPressed: () {
                            onDateSelected(tempSelectedDate);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                  ),
                ),
              ),
          );
        },
      );
    },
  );
}
