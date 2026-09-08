import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// Top bar with Stadium selector dropdown, Month/Year date picker button, and 14-day horizontal strip.
class OwnerBookingsFilterBar extends StatelessWidget {
  final List<Stadium> stadiums;
  final Stadium? selectedStadium;
  final DateTime baseDate;
  final int selectedDayIndex;
  final ValueChanged<Stadium> onStadiumChanged;
  final VoidCallback onSelectDate;
  final ValueChanged<int> onDaySelected;

  const OwnerBookingsFilterBar({
    super.key,
    required this.stadiums,
    required this.selectedStadium,
    required this.baseDate,
    required this.selectedDayIndex,
    required this.onStadiumChanged,
    required this.onSelectDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Row(
            children: [
              // 1. Stadium Selector Dropdown
              Expanded(
                child: stadiums.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.lg),
                          border: Border.all(color: VSPColors.divider, width: 0.5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Stadium>(
                            value: selectedStadium,
                            dropdownColor: VSPColors.surface,
                            icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
                            isExpanded: true,
                            items: stadiums.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s.name,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: VSPColors.textPrimary,
                                      fontSize: 13,
                                    ),
                              ),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) onStadiumChanged(val);
                            },
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // 2. Month / Year Calendar Button
              InkWell(
                onTap: onSelectDate,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('MMMM, yyyy', Localizations.localeOf(context).toString())
                            .format(baseDate.add(Duration(days: selectedDayIndex))),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: VSPColors.textPrimary,
                              fontSize: 13,
                            ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. 14-Day Horizontal Calendar Strip
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            physics: const BouncingScrollPhysics(),
            itemCount: 14,
            itemBuilder: (context, index) {
              final date = baseDate.add(Duration(days: index));
              final bool isSelected = index == selectedDayIndex;
              final String dayName =
                  DateFormat('E', Localizations.localeOf(context).toString()).format(date).toUpperCase();

              return GestureDetector(
                onTap: () => onDaySelected(index),
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? VSPColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: isSelected ? VSPColors.accent : VSPColors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayName,
                        style: TextStyle(
                          color: isSelected ? VSPColors.background : VSPColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),
        const Divider(color: VSPColors.divider, thickness: 1),
      ],
    );
  }
}
