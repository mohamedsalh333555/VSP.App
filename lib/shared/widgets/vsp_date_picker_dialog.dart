import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// 📅 VSP Custom 3-Step Date Picker Dialog
/// Centered Dialog with 3 sequential steps: Year -> Month -> Day
/// Large numbers listed vertically for optimal UX.
Future<DateTime?> showVSPDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  int minYear = 1940,
  int? maxYear,
}) async {
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (ctx) => VSPDatePickerDialog(
      initialDate: initialDate,
      minYear: minYear,
      maxYear: maxYear ?? (DateTime.now().year - 10),
    ),
  );
}

class VSPDatePickerDialog extends StatefulWidget {
  final DateTime? initialDate;
  final int minYear;
  final int maxYear;

  const VSPDatePickerDialog({
    super.key,
    this.initialDate,
    required this.minYear,
    required this.maxYear,
  });

  @override
  State<VSPDatePickerDialog> createState() => _VSPDatePickerDialogState();
}

class _VSPDatePickerDialogState extends State<VSPDatePickerDialog> {
  int _currentStep = 0; // 0: Year, 1: Month, 2: Day
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;

  final ScrollController _scrollController = ScrollController();

  static const List<Map<String, dynamic>> _months = [
    {'number': 1, 'nameAr': 'يناير', 'nameEn': 'January'},
    {'number': 2, 'nameAr': 'فبراير', 'nameEn': 'February'},
    {'number': 3, 'nameAr': 'مارس', 'nameEn': 'March'},
    {'number': 4, 'nameAr': 'أبريل', 'nameEn': 'April'},
    {'number': 5, 'nameAr': 'مايو', 'nameEn': 'May'},
    {'number': 6, 'nameAr': 'يونيو', 'nameEn': 'June'},
    {'number': 7, 'nameAr': 'يوليو', 'nameEn': 'July'},
    {'number': 8, 'nameAr': 'أغسطس', 'nameEn': 'August'},
    {'number': 9, 'nameAr': 'سبتمبر', 'nameEn': 'September'},
    {'number': 10, 'nameAr': 'أكتوبر', 'nameEn': 'October'},
    {'number': 11, 'nameAr': 'نوفمبر', 'nameEn': 'November'},
    {'number': 12, 'nameAr': 'ديسمبر', 'nameEn': 'December'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedYear = widget.initialDate!.year;
      _selectedMonth = widget.initialDate!.month;
      _selectedDay = widget.initialDate!.day;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _finishSelection() {
    if (_selectedYear != null && _selectedMonth != null && _selectedDay != null) {
      final date = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
      Navigator.pop(context, date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            maxWidth: 420,
          ),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.dialog),
            border: Border.all(color: VSPColors.divider, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Close
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.calendar_1,
                        color: VSPColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isAr ? 'اختر تاريخ الميلاد' : 'Select Date of Birth',
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Iconsax.close_circle, color: VSPColors.textSecondary, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(color: VSPColors.divider, height: 1),

              // Step Progress Tracker Header (1. السنة -> 2. الشهر -> 3. اليوم)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _buildStepChip(
                      stepIndex: 0,
                      title: isAr ? 'السنة' : 'Year',
                      value: _selectedYear != null ? '$_selectedYear' : null,
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: VSPColors.textMuted, size: 18),
                    const SizedBox(width: 6),
                    _buildStepChip(
                      stepIndex: 1,
                      title: isAr ? 'الشهر' : 'Month',
                      value: _selectedMonth != null
                          ? (isAr ? _months[_selectedMonth! - 1]['nameAr'] : '$_selectedMonth')
                          : null,
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: VSPColors.textMuted, size: 18),
                    const SizedBox(width: 6),
                    _buildStepChip(
                      stepIndex: 2,
                      title: isAr ? 'اليوم' : 'Day',
                      value: _selectedDay != null ? '$_selectedDay' : null,
                    ),
                  ],
                ),
              ),

              const Divider(color: VSPColors.divider, height: 1),

              // Step Content Body (Vertical List of Large Numbers)
              Expanded(
                child: _buildStepListContent(isAr),
              ),

              const Divider(color: VSPColors.divider, height: 1),

              // Actions Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() => _currentStep--);
                          },
                          child: Text(
                            isAr ? 'السابق' : 'Back',
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (_selectedYear != null && _selectedMonth != null && _selectedDay != null)
                            ? _finishSelection
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                          ),
                        ),
                        child: Text(
                          isAr ? 'تأكيد التاريخ' : 'Confirm Date',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepChip({
    required int stepIndex,
    required String title,
    String? value,
  }) {
    final isCurrent = _currentStep == stepIndex;
    final isDone = value != null;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Allow clicking previous completed steps to change selection
          if (stepIndex == 0 || (stepIndex == 1 && _selectedYear != null) || (stepIndex == 2 && _selectedMonth != null)) {
            setState(() => _currentStep = stepIndex);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isCurrent
                ? VSPColors.accent.withValues(alpha: 0.18)
                : (isDone ? VSPColors.surfaceAlt : Colors.transparent),
            borderRadius: BorderRadius.circular(VSPRadius.sm),
            border: Border.all(
              color: isCurrent ? VSPColors.accent : (isDone ? VSPColors.borderLight : Colors.transparent),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isCurrent ? VSPColors.accent : VSPColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent ? Colors.white : (isDone ? VSPColors.textPrimary : VSPColors.textMuted),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepListContent(bool isAr) {
    if (_currentStep == 0) {
      // Step 1: Years (List of large numbers ordered vertically)
      final List<int> years = List.generate(
        widget.maxYear - widget.minYear + 1,
        (index) => widget.maxYear - index,
      );

      return ListView.separated(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final year = years[index];
          final isSelected = _selectedYear == year;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedYear = year;
                _currentStep = 1; // Move to month step
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: isSelected ? VSPColors.accent : VSPColors.borderLight,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  '$year',
                  style: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else if (_currentStep == 1) {
      // Step 2: Months (List of large numbers & names ordered vertically)
      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        itemCount: _months.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final monthItem = _months[index];
          final monthNum = monthItem['number'] as int;
          final isSelected = _selectedMonth == monthNum;
          final monthName = isAr ? monthItem['nameAr'] : monthItem['nameEn'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMonth = monthNum;
                _currentStep = 2; // Move to day step
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: isSelected ? VSPColors.accent : VSPColors.borderLight,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black.withValues(alpha: 0.15) : VSPColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        monthNum.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: isSelected ? Colors.black : VSPColors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    monthName,
                    style: TextStyle(
                      color: isSelected ? Colors.black : VSPColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Step 3: Days (List of large numbers ordered vertically)
      final totalDays = _daysInMonth(_selectedYear ?? DateTime.now().year, _selectedMonth ?? 1);
      final List<int> days = List.generate(totalDays, (index) => index + 1);

      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _selectedDay == day;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDay = day;
              });
              _finishSelection();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: isSelected ? VSPColors.accent : VSPColors.borderLight,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }
}
