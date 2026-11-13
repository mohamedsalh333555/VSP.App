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
  required DateTime operationalBaseDate,
  required ValueChanged<DateTime> onDateSelected,
}) {
  final l10n = AppLocalizations.of(context)!;
  final firstBookableDay = DateTime(operationalBaseDate.year, operationalBaseDate.month, operationalBaseDate.day);
  showDialog(
    context: context,
    useSafeArea: true,
    barrierColor: VSPColors.background.withValues(alpha: 0.8),
    builder: (context) {
      final DateTime todayMonth = DateTime(firstBookableDay.year, firstBookableDay.month);
      final DateTime maxMonth = DateTime(firstBookableDay.year, firstBookableDay.month + 3);
      final DateTime lastBookableDay = DateTime(maxMonth.year, maxMonth.month + 1, 0);
      final DateTime normalizedInitialDate =
          DateTime(initialDate.year, initialDate.month, initialDate.day);
      // A stale parent selection must not let Apply submit an expired or
      // out-of-window booking day without a valid selection from this dialog.
      DateTime tempSelectedDate =
          normalizedInitialDate.isBefore(firstBookableDay) ||
                  normalizedInitialDate.isAfter(lastBookableDay)
              ? firstBookableDay
              : normalizedInitialDate;
      DateTime currentMonth = DateTime(tempSelectedDate.year, tempSelectedDate.month);

      return StatefulBuilder(
        builder: (context, setModalState) {
          final mediaQuery = MediaQuery.of(context);
          final isRtl = Directionality.of(context) == TextDirection.rtl;
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          final availableHeight = mediaQuery.size.height -
              mediaQuery.viewInsets.vertical -
              (VSPSpacing.xl * 2);
          final firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
          final leadingCells = firstWeekday - DateTime.monday;
          final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
          final weekRows = (leadingCells + daysInMonth + 6) ~/ 7;

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
                            style: const TextStyle(color: VSPColors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  Text(
                    isArabic
                        ? 'اختيار التاريخ لا يؤكد توفر المواعيد؛ ستظهر المواعيد بعد اختيار اليوم.'
                        : 'Selecting a date does not confirm availability; slots appear after choosing a day.',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  Row(
                    children: List.generate(7, (index) {
                      final weekday = DateTime(2024, 1, 1 + index); // Monday first.
                      return Expanded(
                        child: Text(
                          DateFormat('E', Localizations.localeOf(context).toString()).format(weekday),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: VSPSpacing.xs),
                  SizedBox(
                    // Six-week months need more than the previous fixed 240px.
                    // Keep each target at least 48px high and let the dialog scroll.
                    height: weekRows * 48.0 + (weekRows - 1) * 4.0,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisExtent: 48,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: daysInMonth + leadingCells,
                      itemBuilder: (context, index) {
                        final dayOffset = index - leadingCells;
                        if (dayOffset < 0) return const SizedBox();
                        final day = dayOffset + 1;
                        final date = DateTime(currentMonth.year, currentMonth.month, day);
                        final isSelected = date.year == tempSelectedDate.year &&
                            date.month == tempSelectedDate.month &&
                            date.day == tempSelectedDate.day;
                        final isPastDate = date.isBefore(firstBookableDay);

                        final readableDate = DateFormat(
                          'EEEE, d MMMM yyyy',
                          Localizations.localeOf(context).toString(),
                        ).format(date);
                        void selectDay() {
                          setModalState(() {
                            tempSelectedDate = date;
                          });
                        }

                        return Semantics(
                          button: true,
                          enabled: !isPastDate,
                          selected: isSelected,
                          label: isArabic
                              ? 'تاريخ الحجز: $readableDate'
                              : 'Booking date: $readableDate',
                          onTap: isPastDate ? null : selectDay,
                          child: ExcludeSemantics(
                            child: InkWell(
                              onTap: isPastDate ? null : selectDay,
                              child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? VSPColors.accent
                                  : (isPastDate ? VSPColors.surfaceAlt : VSPColors.transparent),
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
