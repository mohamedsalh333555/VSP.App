import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// محدد المركز المفضل الموحد لتطبيق VSP لضمان تطابق التصميم والبيانات عبر كل شاشات التسجيل
class VSPPositionSelector extends StatelessWidget {
  final String? selectedPosition;
  final ValueChanged<String> onPositionSelected;
  final String sport;

  const VSPPositionSelector({
    super.key,
    required this.selectedPosition,
    required this.onPositionSelected,
    this.sport = 'Football',
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final sportPositions = SportPositionsRegistry.getPositionsForSport(sport);
    final positions = sportPositions.map((pos) => {
      'code': pos.code,
      'label': isAr ? pos.nameAr : pos.nameEn,
    }).toList();

    return Row(
      children: positions.map((pos) {
        final code = pos['code'] as String;
        final label = pos['label'] as String;
        final isSelected = selectedPosition == code;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPositionSelected(code);
                  },
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? VSPColors.accent.withValues(alpha: 0.15)
                          : VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(
                        color: isSelected ? VSPColors.accent : VSPColors.borderLight,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: VSPColors.accent.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
