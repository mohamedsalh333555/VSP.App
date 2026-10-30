import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: VSPDSSpacing.xxs),
            child: AnimatedContainer(
              duration: VSPDSMotion.fast,
              curve: Curves.easeOutCubic,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPositionSelected(code);
                  },
                  borderRadius: BorderRadius.circular(VSPDSRadius.md),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: VSPDSAccessibility.minimumTapTarget,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: VSPDSSpacing.sm, horizontal: VSPDSSpacing.xxs),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? VSPDSSemanticColors.accentSoft
                          : VSPDSSemanticColors.surface,
                      borderRadius: BorderRadius.circular(VSPDSRadius.md),
                      border: Border.all(
                        color: isSelected ? VSPDSSemanticColors.accent : VSPDSColors.white15,
                        width: isSelected ? VSPDSBorders.fieldFocus : VSPDSBorders.standard,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: VSPDSComponentEffects.buttonShadow.color,
                                blurRadius: VSPDSComponentEffects.buttonShadow.blurRadius,
                                offset: VSPDSComponentEffects.buttonShadow.offset,
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
                            color: isSelected ? VSPDSSemanticColors.accent : VSPDSSemanticColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: VSPDSTypography.bodySmall.fontSize ?? 13,
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
