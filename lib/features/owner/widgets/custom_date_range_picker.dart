import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;

  const CustomDateRangePicker({super.key, this.initialDateRange});

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime _focusedMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.initialDateRange?.start ?? DateTime.now();
    _startDate = widget.initialDateRange?.start;
    _endDate = widget.initialDateRange?.end;
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      if (_startDate != null && _endDate == null && day.isAfter(_startDate!)) {
        _endDate = day;
      } else {
        _startDate = day;
        _endDate = null;
      }
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInRange(DateTime day) {
    if (_startDate == null || _endDate == null) return false;
    return day.isAfter(_startDate!) && day.isBefore(_endDate!);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header (Month Year & Nav)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left, color: VSPColors.textPrimary),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right, color: VSPColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: VSPSpacing.md),

            // 2. Date Inputs Display
            Row(
              children: [
                Expanded(child: _buildDateInput(_startDate, AppLocalizations.of(context)!.startDate)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-', style: TextStyle(color: VSPColors.textSecondary)),
                ),
                Expanded(child: _buildDateInput(_endDate, AppLocalizations.of(context)!.endDate)),
              ],
            ),
            const SizedBox(height: VSPSpacing.md),

            // 3. Calendar Grid
            _buildWeekDays(),
            const SizedBox(height: VSPSpacing.sm),
            SizedBox(
              height: 240, // Fixed height for calendar days
              child: _buildDaysGrid(),
            ),
            const SizedBox(height: VSPSpacing.md),

            // 4. Action Buttons (Footer)
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(context)!.resetLabel,
                    height: 48,
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                    onPressed: () {
                       setState(() {
                         _startDate = null;
                         _endDate = null;
                       });
                    },
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(context)!.apply,
                    height: 48,
                    onPressed: (_startDate != null && _endDate != null)
                        ? () {
                            Navigator.pop(context, DateTimeRange(start: _startDate!, end: _endDate!));
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInput(DateTime? date, String placeholder) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: VSPSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: VSPColors.divider),
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: Center(
        child: Text(
          date != null ? DateFormat('MMM dd, yyyy').format(date) : placeholder,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: date != null ? VSPColors.textPrimary : VSPColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekDays() {
    final days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sat', 'Su'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((d) => SizedBox(
        width: 30,
        child: Center(child: Text(d, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary))),
      )).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun (ISO 8601)

    // Calculate total grid cells needed
    final totalCells = daysInMonth + (firstWeekday - 1); 

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < firstWeekday - 1) {
          return const SizedBox(); // Empty slots before 1st day
        }
        
        final dayNum = index - (firstWeekday - 1) + 1;
        final currentDay = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
        
        bool isSelected = _isSameDay(currentDay, _startDate) || _isSameDay(currentDay, _endDate);
        bool inRange = _isInRange(currentDay);
        bool isToday = _isSameDay(currentDay, DateTime.now());

        return GestureDetector(
          onTap: () => _onDaySelected(currentDay),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? VSPColors.accent : (inRange ? VSPColors.accent.withValues(alpha: 0.2) : Colors.transparent),
              shape: BoxShape.circle,
              border: isToday && !isSelected && !inRange
                  ? Border.all(color: VSPColors.accent, width: 1)
                  : null,
            ),
            child: Center(
              child: Text(
                '$dayNum',
                style: TextStyle(
                  color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
      // Safely handle extra item count logic or padding if needed in future
    );
  }
}

