import 'package:flutter/material.dart';
import '../tokens/vsp_design_tokens.dart';

/// Equal-width tabs with a directional pill and content-driven height.
class VSPSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final TextStyle? textStyle;

  const VSPSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.textStyle,
  }) : assert(labels.length > 0),
       assert(selectedIndex >= 0 && selectedIndex < labels.length);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, _) {
        final scale = MediaQuery.textScalerOf(context);
        final height = scale.scale(48).clamp(48.0, 80.0).toDouble();

        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: VSPDSSemanticColors.surface,
            borderRadius: BorderRadius.circular(VSPDSRadius.md),
            border: Border.all(color: VSPDSSemanticColors.border),
          ),
          child: SizedBox(
            height: height,
            child: Row(
              children: List.generate(labels.length, (index) {
                final selected = index == selectedIndex;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    inMutuallyExclusiveGroup: true,
                    label: labels[index],
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(VSPDSRadius.sm),
                        onTap: () => onSelected(index),
                        child: AnimatedContainer(
                          duration: reduceMotion
                              ? Duration.zero
                              : VSPDSMotion.segmentedSelection,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? VSPDSSemanticColors.surfaceRaised
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(VSPDSRadius.sm),
                          ),
                          child: Text(
                            labels[index],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: (textStyle ?? VSPDSTypography.compactButton)
                                .copyWith(
                              color: selected
                                  ? VSPDSSemanticColors.textPrimary
                                  : VSPDSSemanticColors.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
