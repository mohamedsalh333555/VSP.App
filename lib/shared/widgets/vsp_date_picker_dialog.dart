import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/utils/vsp_feedback.dart';
import '../../shared/widgets/primary_button.dart';

/// 📅 VSP Custom 3-Step Date Picker Dialog
/// Fully aligned with VSP Design System (Tokens, Neon Glow, Haptics, Glassmorphism)
Future<DateTime?> showVSPDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  int minYear = 1940,
  int? maxYear,
}) async {
  VSPFeedback.triggerTap();
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.8),
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
      VSPFeedback.triggerSuccess();
      final date = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
      Navigator.pop(context, date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.xl),
            border: Border.all(
              color: VSPColors.accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: VSPColors.accent.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header with Neon Accent Avatar & Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: VSPColors.accent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Iconsax.calendar_1_copy,
                        color: VSPColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isAr ? 'اختر تاريخ الميلاد' : 'Select Date of Birth',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        VSPFeedback.triggerTap();
                        Navigator.pop(context);
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.close_circle_copy,
                          color: VSPColors.textSecondary,
                          size: 18,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              const Divider(color: VSPColors.divider, height: 1),

              // 2. VSP Unified Step Tracker Chips (Year -> Month -> Day)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _buildStepChip(
                      stepIndex: 0,
                      title: isAr ? 'السنة' : 'Year',
                      value: _selectedYear != null ? '$_selectedYear' : null,
                      isAr: isAr,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isAr ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                        color: VSPColors.textMuted,
                        size: 14,
                      ),
                    ),
                    _buildStepChip(
                      stepIndex: 1,
                      title: isAr ? 'الشهر' : 'Month',
                      value: _selectedMonth != null
                          ? (isAr ? _months[_selectedMonth! - 1]['nameAr'] : '$_selectedMonth')
                          : null,
                      isAr: isAr,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isAr ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                        color: VSPColors.textMuted,
                        size: 14,
                      ),
                    ),
                    _buildStepChip(
                      stepIndex: 2,
                      title: isAr ? 'اليوم' : 'Day',
                      value: _selectedDay != null ? '$_selectedDay' : null,
                      isAr: isAr,
                    ),
                  ],
                ),
              ),

              const Divider(color: VSPColors.divider, height: 1),

              // 3. Step Content Body (Vertical List of Unified Cards)
              Expanded(
                child: _buildStepListContent(isAr),
              ),

              const Divider(color: VSPColors.divider, height: 1),

              // 4. VSP Actions Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: () {
                            VSPFeedback.triggerTap();
                            setState(() => _currentStep--);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                            ),
                          ),
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
                      child: PrimaryButton(
                        text: isAr ? 'تأكيد التاريخ' : 'Confirm Date',
                        color: VSPColors.accent,
                        textColor: Colors.black,
                        onPressed: (_selectedYear != null && _selectedMonth != null && _selectedDay != null)
                            ? _finishSelection
                            : null,
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
    required bool isAr,
  }) {
    final isCurrent = _currentStep == stepIndex;
    final isDone = value != null;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (stepIndex == 0 || (stepIndex == 1 && _selectedYear != null) || (stepIndex == 2 && _selectedMonth != null)) {
            VSPFeedback.triggerTap();
            setState(() => _currentStep = stepIndex);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? VSPColors.accent.withValues(alpha: 0.18)
                : (isDone ? VSPColors.surfaceAlt : VSPColors.surfaceAlt.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(
              color: isCurrent
                  ? VSPColors.accent
                  : (isDone ? VSPColors.accent.withValues(alpha: 0.3) : VSPColors.divider),
              width: isCurrent ? 2.0 : 1.0,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: VSPColors.accent.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isCurrent ? VSPColors.accent : VSPColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value ?? (isAr ? 'اختر' : 'Select'),
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
      // Step 1: Years List
      final List<int> years = List.generate(
        widget.maxYear - widget.minYear + 1,
        (index) => widget.maxYear - index,
      );

      return ListView.separated(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final year = years[index];
          final isSelected = _selectedYear == year;

          return GestureDetector(
            onTap: () {
              VSPFeedback.triggerTap();
              setState(() {
                _selectedYear = year;
                _currentStep = 1; // Auto advance to month step
              });
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
    } else if (_currentStep == 1) {
      // Step 2: Months List
      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _months.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final monthItem = _months[index];
          final monthNum = monthItem['number'] as int;
          final isSelected = _selectedMonth == monthNum;
          final monthName = isAr ? monthItem['nameAr'] : monthItem['nameEn'];

          return GestureDetector(
            onTap: () {
              VSPFeedback.triggerTap();
              setState(() {
                _selectedMonth = monthNum;
                _currentStep = 2; // Auto advance to day step
              });
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
    } else {
      // Step 3: Days List
      final totalDays = _daysInMonth(_selectedYear ?? DateTime.now().year, _selectedMonth ?? 1);
      final List<int> days = List.generate(totalDays, (index) => index + 1);

      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _selectedDay == day;

          return GestureDetector(
            onTap: () {
              VSPFeedback.triggerTap();
              setState(() {
                _selectedDay = day;
              });
              _finishSelection();
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
}

