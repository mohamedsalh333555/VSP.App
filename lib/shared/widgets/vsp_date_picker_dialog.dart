import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/utils/vsp_feedback.dart';
import '../../shared/widgets/primary_button.dart';
import 'date_picker/vsp_date_picker_calculator.dart';
import 'date_picker/vsp_date_picker_step_chip.dart';
import 'date_picker/vsp_date_picker_step_views.dart';

/// VSP Custom 3-Step Date Picker Dialog
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
 VSPShadow.strong,
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
 decoration: const BoxDecoration(
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
 VspDatePickerStepChip(
 stepIndex: 0,
 currentStep: _currentStep,
 title: isAr ? 'السنة' : 'Year',
 value: _selectedYear != null ? '$_selectedYear' : null,
 isAr: isAr,
 isEnabled: VspDatePickerCalculator.canNavigateToStep(
 targetStep: 0,
 selectedYear: _selectedYear,
 selectedMonth: _selectedMonth,
 ),
 onTap: () => setState(() => _currentStep = 0),
 ),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 4),
 child: Icon(
 isAr ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
 color: VSPColors.textMuted,
 size: 14,
 ),
 ),
 VspDatePickerStepChip(
 stepIndex: 1,
 currentStep: _currentStep,
 title: isAr ? 'الشهر' : 'Month',
 value: _selectedMonth != null
 ? VspDatePickerCalculator.getMonthName(_selectedMonth!, isArabic: isAr)
 : null,
 isAr: isAr,
 isEnabled: VspDatePickerCalculator.canNavigateToStep(
 targetStep: 1,
 selectedYear: _selectedYear,
 selectedMonth: _selectedMonth,
 ),
 onTap: () => setState(() => _currentStep = 1),
 ),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 4),
 child: Icon(
 isAr ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
 color: VSPColors.textMuted,
 size: 14,
 ),
 ),
 VspDatePickerStepChip(
 stepIndex: 2,
 currentStep: _currentStep,
 title: isAr ? 'اليوم' : 'Day',
 value: _selectedDay != null ? '$_selectedDay' : null,
 isAr: isAr,
 isEnabled: VspDatePickerCalculator.canNavigateToStep(
 targetStep: 2,
 selectedYear: _selectedYear,
 selectedMonth: _selectedMonth,
 ),
 onTap: () => setState(() => _currentStep = 2),
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

  Widget _buildStepListContent(bool isAr) {
    if (_currentStep == 0) {
      return VspDatePickerYearStep(
        controller: _scrollController,
        minYear: widget.minYear,
        maxYear: widget.maxYear,
        selectedYear: _selectedYear,
        onYearSelected: (year) {
          setState(() {
            _selectedYear = year;
            _currentStep = 1;
          });
        },
      );
    } else if (_currentStep == 1) {
      return VspDatePickerMonthStep(
        selectedMonth: _selectedMonth,
        isAr: isAr,
        onMonthSelected: (month) {
          setState(() {
            _selectedMonth = month;
            _currentStep = 2;
          });
        },
      );
    } else {
      return VspDatePickerDayStep(
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        selectedDay: _selectedDay,
        onDaySelected: (day) {
          setState(() {
            _selectedDay = day;
          });
          _finishSelection();
        },
      );
    }
  }
}
