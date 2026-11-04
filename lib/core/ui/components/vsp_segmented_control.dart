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
    final alignment = labels.length == 1
        ? 0.0 : -1.0 + 2.0 * selectedIndex / (labels.length - 1);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: VSPDSSemanticColors.surface,
        borderRadius: BorderRadius.circular(VSPDSRadius.full),
        border: Border.all(color: VSPDSSemanticColors.border, width: 0.5),
      ),
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: AnimatedAlign(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero : VSPDSMotion.segmentedSelection,
          curve: Curves.easeInOut,
          alignment: AlignmentDirectional(alignment, 0),
          child: FractionallySizedBox(
            widthFactor: 1 / labels.length,
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(
              color: VSPDSSemanticColors.accent,
              borderRadius: BorderRadius.circular(VSPDSRadius.full),
            )),
          ),
        ))),
        IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(labels.length, (index) {
            final selected = index == selectedIndex;
            return Expanded(child: Semantics(
              button: true,
              selected: selected,
              inMutuallyExclusiveGroup: true,
              excludeSemantics: true,
              label: labels[index],
              onTap: () => onSelected(index),
              child: InkWell(
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(VSPDSRadius.full),
                onTap: () => onSelected(index),
                child: Container(
                  constraints: const BoxConstraints(minHeight: VSPDSAccessibility.minimumTapTarget),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: VSPDSSpacing.xs, vertical: VSPDSSpacing.xs),
                  child: Text(labels[index], textAlign: TextAlign.center,
                    style: (textStyle ?? VSPDSTypography.compactButton).copyWith(
                      color: selected ? VSPDSColors.black : VSPDSSemanticColors.textSecondary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ));
          }),
        )),
      ]),
    );
  }
}
