import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

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
      backgroundColor: const Color(0xFF1E1E1E), // Dark Grey Background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header (Month Year & Nav)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Agency FB',
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Date Inputs Display
            Row(
              children: [
                Expanded(child: _buildDateInput(_startDate, 'Start Date')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: _buildDateInput(_endDate, 'End Date')),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Calendar Grid
            _buildWeekDays(),
            const SizedBox(height: 8),
            SizedBox(
              height: 240, // Fixed height for calendar days
              child: _buildDaysGrid(),
            ),
            const SizedBox(height: 20),

            // 4. Action Buttons (Footer)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                       setState(() {
                         _startDate = null;
                         _endDate = null;
                       });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 16)), // Text Changed to Reset
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_startDate != null && _endDate != null)
                        ? () {
                            Navigator.pop(context, DateTimeRange(start: _startDate!, end: _endDate!));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: AppTheme.neonGreen.withValues(alpha: 0.3),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          date != null ? DateFormat('MMM dd, yyyy').format(date) : placeholder,
          style: TextStyle(
            color: date != null ? Colors.white : Colors.grey,
            fontSize: 14,
            fontFamily: 'Agency FB',
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
        child: Center(child: Text(d, style: const TextStyle(color: Colors.grey, fontSize: 12))),
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
              color: isSelected ? AppTheme.neonGreen : (inRange ? AppTheme.neonGreen.withValues(alpha: 0.2) : Colors.transparent),
              shape: BoxShape.circle,
              border: isToday && !isSelected && !inRange
                  ? Border.all(color: AppTheme.neonGreen, width: 1) // Glowing effect for today
                  : null,
            ),
            child: Center(
              child: Text(
                '$dayNum',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
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
