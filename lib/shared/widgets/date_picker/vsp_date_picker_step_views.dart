import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'vsp_date_picker_calculator.dart';

/// Step 1: Years List selector
class VspDatePickerYearStep extends StatelessWidget {
  final ScrollController? controller;
  final int minYear;
  final int maxYear;
  final int? selectedYear;
  final ValueChanged<int> onYearSelected;

  const VspDatePickerYearStep({
    super.key,
    this.controller,
    required this.minYear,
    required this.maxYear,
    required this.selectedYear,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> years = VspDatePickerCalculator.generateYears(
      minYear: minYear,
      maxYear: maxYear,
    );

    return ListView.separated(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: years.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final year = years[index];
        final isSelected = selectedYear == year;

        return GestureDetector(
          onTap: () {
            VSPFeedback.triggerTap();
            onYearSelected(year);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(
                color: isSelected ? VSPColors.accent : VSPColors.divider,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: VSPColors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$year',
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isSelected)
                  const Icon(Iconsax.tick_circle_copy, color: Colors.black, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Step 2: Months List selector
class VspDatePickerMonthStep extends StatelessWidget {
  final int? selectedMonth;
  final bool isAr;
  final ValueChanged<int> onMonthSelected;

  const VspDatePickerMonthStep({
    super.key,
    required this.selectedMonth,
    required this.isAr,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: VspDatePickerCalculator.months.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final monthItem = VspDatePickerCalculator.months[index];
        final monthNum = monthItem['number'] as int;
        final isSelected = selectedMonth == monthNum;
        final monthName = VspDatePickerCalculator.getMonthName(monthNum, isArabic: isAr);

        return GestureDetector(
          onTap: () {
            VSPFeedback.triggerTap();
            onMonthSelected(monthNum);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(
                color: isSelected ? VSPColors.accent : VSPColors.divider,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: VSPColors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black.withValues(alpha: 0.18) : VSPColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      monthNum.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: isSelected ? Colors.black : VSPColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    monthName,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Iconsax.tick_circle_copy, color: Colors.black, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Step 3: Days List selector
class VspDatePickerDayStep extends StatelessWidget {
  final int? selectedYear;
  final int? selectedMonth;
  final int? selectedDay;
  final ValueChanged<int> onDaySelected;

  const VspDatePickerDayStep({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final totalDays = VspDatePickerCalculator.daysInMonth(
      selectedYear ?? DateTime.now().year,
      selectedMonth ?? 1,
    );
    final List<int> days = List.generate(totalDays, (index) => index + 1);

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final day = days[index];
        final isSelected = selectedDay == day;

        return GestureDetector(
          onTap: () {
            VSPFeedback.triggerTap();
            onDaySelected(day);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(
                color: isSelected ? VSPColors.accent : VSPColors.divider,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: VSPColors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isSelected)
                  const Icon(Iconsax.tick_circle_copy, color: Colors.black, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
