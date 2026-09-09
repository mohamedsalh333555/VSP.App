import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Form section managing payment status (paid/pending) and shirt color selection.
class TournamentManualTeamOptionsSection extends StatelessWidget {
  final bool isPaidOnCreation;
  final ValueChanged<bool> onPaymentStatusChanged;
  final String selectedPrimaryColor;
  final ValueChanged<String> onColorSelected;

  static const List<Map<String, dynamic>> quickColors = [
    {'name': 'أبيض', 'value': '#FFFFFF', 'color': Colors.white},
    {'name': 'أحمر', 'value': '#EF4444', 'color': Colors.red},
    {'name': 'أزرق', 'value': '#3B82F6', 'color': Colors.blue},
    {'name': 'أخضر', 'value': '#22C55E', 'color': Colors.green},
    {'name': 'أصفر', 'value': '#F59E0B', 'color': Colors.amber},
    {'name': 'أسود', 'value': '#18181B', 'color': Colors.black},
  ];

  const TournamentManualTeamOptionsSection({
    super.key,
    required this.isPaidOnCreation,
    required this.onPaymentStatusChanged,
    required this.selectedPrimaryColor,
    required this.onColorSelected,
  });

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: VSPColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Payment Status
        _buildSectionLabel(isArabic ? 'حالة سداد رسوم الاشتراك:' : 'Payment Status:'),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onPaymentStatusChanged(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isPaidOnCreation ? VSPColors.accent : VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: isPaidOnCreation ? VSPColors.accent : VSPColors.divider,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isPaidOnCreation ? Colors.black : VSPColors.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'تم الدفع ' : 'Paid ',
                        style: TextStyle(
                          color: isPaidOnCreation ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onPaymentStatusChanged(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !isPaidOnCreation
                        ? VSPColors.warning.withValues(alpha: 0.2)
                        : VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: !isPaidOnCreation ? VSPColors.warning : VSPColors.divider,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        color: !isPaidOnCreation ? VSPColors.warning : VSPColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'معلق / غير مدفوع ' : 'Pending ',
                        style: TextStyle(
                          color: !isPaidOnCreation ? VSPColors.warning : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Shirt Color
        _buildSectionLabel(isArabic ? 'لون قميص الفريق:' : 'Shirt Color:'),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: quickColors.length,
            itemBuilder: (context, index) {
              final item = quickColors[index];
              final isSelected = selectedPrimaryColor == item['value'];
              return GestureDetector(
                onTap: () => onColorSelected(item['value'] as String),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? VSPColors.accent : VSPColors.divider,
                      width: isSelected ? 3.0 : 1.0,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Iconsax.tick_circle_copy,
                          color: item['color'] == Colors.white ? Colors.black : Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
