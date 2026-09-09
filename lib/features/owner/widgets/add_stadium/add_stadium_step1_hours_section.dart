import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

class AddStadiumStep1HoursSection extends StatelessWidget {
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isSplitShift;
  final List<Map<String, TimeOfDay?>> breakTimes;
  final bool isSplitShiftValid;
  final Function(bool isMainStart) onSelectTime;
  final ValueChanged<bool> onToggleSplitShift;
  final Function(int index, bool isStart) onSelectBreakTime;
  final VoidCallback onAddBreak;
  final ValueChanged<int> onRemoveBreak;

  const AddStadiumStep1HoursSection({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.isSplitShift,
    required this.breakTimes,
    required this.isSplitShiftValid,
    required this.onSelectTime,
    required this.onToggleSplitShift,
    required this.onSelectBreakTime,
    required this.onAddBreak,
    required this.onRemoveBreak,
  });

  String _formatTime(TimeOfDay? time, String placeholder) {
    if (time == null) return placeholder;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Widget _buildTimeBox(String text, {bool isSelected = false}) {
    return Container(
      height: VSPSize.inputHeight,
      decoration: BoxDecoration(
        color: isSelected ? VSPColors.accentSoft : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(
          color: isSelected ? VSPColors.accent : VSPColors.accent.withValues(alpha: 0.1),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.workingHours,
          style: const TextStyle(color: VSPColors.textSecondary),
        ),
        const SizedBox(height: VSPSpacing.xs),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onSelectTime(true),
                child: _buildTimeBox(
                  _formatTime(startTime, l10n.start),
                  isSelected: startTime != null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onSelectTime(false),
                child: _buildTimeBox(
                  _formatTime(endTime, l10n.end),
                  isSelected: endTime != null,
                ),
              ),
            ),
          ],
        ),
        if (endTime != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Builder(builder: (context) {
                  final selectedEndStr = _formatTime(endTime, '');
                  return Text(
                    isArabic
                        ? 'ملاحظة: اختيار وقت الإغلاق ($selectedEndStr) يعني أن الملعب يغلق فعلياً وينتهي آخر حجز في هذا الوقت.'
                        : 'Note: Selecting closing time ($selectedEndStr) means the pitch actually closes and the last booking ends at this time.',
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        // Break Time Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.setDailyBreak,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VSPColors.textSecondary,
                  ),
            ),
            Switch.adaptive(
              value: isSplitShift,
              onChanged: onToggleSplitShift,
              activeColor: VSPColors.accent,
            ),
          ],
        ),
        if (isSplitShift) ...[
          const SizedBox(height: 8),
          ...breakTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final bt = entry.value;
            final bStart = bt['start'];
            final bEnd = bt['end'];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0) const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'فترة راحة ${index + 1}' : 'Break ${index + 1}',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (breakTimes.length > 1)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Iconsax.trash_copy,
                          color: VSPColors.error,
                          size: 20,
                        ),
                        onPressed: () => onRemoveBreak(index),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSelectBreakTime(index, true),
                        child: _buildTimeBox(
                          _formatTime(bStart, l10n.breakStart),
                          isSelected: bStart != null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSelectBreakTime(index, false),
                        child: _buildTimeBox(
                          _formatTime(bEnd, l10n.breakEnd),
                          isSelected: bEnd != null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Align(
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddBreak,
              icon: const Icon(Iconsax.add_circle_copy, color: VSPColors.accent, size: 18),
              label: Text(
                isArabic ? 'إضافة فترة راحة أخرى' : 'Add Another Break',
                style: const TextStyle(color: VSPColors.accent, fontSize: 13),
              ),
            ),
          ),
          if (!isSplitShiftValid) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VSPColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                border: Border.all(color: VSPColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'ساعات الراحة يجب أن تكون داخل مواعيد العمل الرسمية للملعب!'
                          : 'Break hours must fall strictly inside the opening and closing hours!',
                      style: const TextStyle(color: VSPColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
