import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';

class QuickBookingDurationSection extends StatelessWidget {
  final List<int> availableDurations;
  final int selectedDurationMinutes;
  final ValueChanged<int> onDurationChanged;
  final int maxAvailableMinutes;
  final String nextObstacleType;
  final DateTime? nextObstacleTime;

  const QuickBookingDurationSection({
    super.key,
    required this.availableDurations,
    required this.selectedDurationMinutes,
    required this.onDurationChanged,
    required this.maxAvailableMinutes,
    required this.nextObstacleType,
    this.nextObstacleTime,
  });

  String _formatDurationLabel(int minutes, bool isAr) {
    if (minutes == 30) return isAr ? 'نصف ساعة (30 د)' : '30 Mins';
    if (minutes == 60) return isAr ? 'ساعة (60 د)' : '1 Hour';
    if (minutes == 90) return isAr ? 'ساعة ونصف (90 د)' : '1.5 Hours';
    if (minutes == 120) return isAr ? 'ساعتان (120 د)' : '2 Hours';
    if (minutes == 150) return isAr ? 'ساعتان ونصف' : '2.5 Hours';
    if (minutes == 180) return isAr ? '3 ساعات' : '3 Hours';
    if (minutes == 240) return isAr ? '4 ساعات' : '4 Hours';
    final double hours = minutes / 60.0;
    final str = hours == hours.toInt() ? '${hours.toInt()}' : hours.toStringAsFixed(1);
    return isAr ? '$str ساعة' : '$str Hours';
  }

  Widget _buildDurationChip(int minutes, String label, {bool isExpanded = false}) {
    final isSelected = selectedDurationMinutes == minutes;
    final widgetChild = GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onDurationChanged(minutes);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(
            color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );

    if (isExpanded) {
      return Expanded(child: widgetChild);
    }
    return widgetChild;
  }

  String _getObstacleHelperText(bool isAr) {
    final hours = maxAvailableMinutes / 60.0;
    final hoursStr = hours == hours.toInt() ? '${hours.toInt()}' : hours.toStringAsFixed(1);
    final nextTimeStr = nextObstacleTime != null
        ? AppDateFormatter.formatTime(nextObstacleTime!.toLocal(), isAr ? 'ar' : 'en')
        : '';

    if (nextObstacleType == 'break') {
      return isAr
          ? 'المتاح حتى فترة الراحة: $hoursStr ساعة${nextTimeStr.isNotEmpty ? ' (حتى $nextTimeStr)' : ''}'
          : 'Available until Break Time: $hoursStr hrs${nextTimeStr.isNotEmpty ? ' (until $nextTimeStr)' : ''}';
    } else if (nextObstacleType == 'booking') {
      return isAr
          ? 'المتاح قبل الحجز التالي: $hoursStr ساعة${nextTimeStr.isNotEmpty ? ' (حتى $nextTimeStr)' : ''}'
          : 'Available before next booking: $hoursStr hrs${nextTimeStr.isNotEmpty ? ' (until $nextTimeStr)' : ''}';
    } else if (nextObstacleType == 'closing') {
      return isAr
          ? 'المتاح حتى نهاية ساعات العمل: $hoursStr ساعة${nextTimeStr.isNotEmpty ? ' (حتى $nextTimeStr)' : ''}'
          : 'Available until closing: $hoursStr hrs${nextTimeStr.isNotEmpty ? ' (until $nextTimeStr)' : ''}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final obstacleText = _getObstacleHelperText(isAr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr ? 'مدة الحجز (عدد الساعات)' : 'Booking Duration',
          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Evenly spaced chips if <= 3, otherwise horizontally scrollable
        if (availableDurations.length <= 3)
          Row(
            children: availableDurations.map((mins) {
              final index = availableDurations.indexOf(mins);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: isAr ? (index > 0 ? 6 : 0) : 0,
                    left: isAr ? 0 : (index > 0 ? 6 : 0),
                  ),
                  child: _buildDurationChip(mins, _formatDurationLabel(mins, isAr)),
                ),
              );
            }).toList(),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: availableDurations.map((mins) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildDurationChip(mins, _formatDurationLabel(mins, isAr)),
                );
              }).toList(),
            ),
          ),

        // Obstacle warning note if any
        if (obstacleText.isNotEmpty && maxAvailableMinutes <= 360) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  nextObstacleType == 'break' ? Iconsax.coffee_copy : Iconsax.clock_copy,
                  color: VSPColors.accent,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    obstacleText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
