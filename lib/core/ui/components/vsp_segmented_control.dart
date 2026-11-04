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
        ? 0.0
        : -1.0 + 2.0 * selectedIndex / (labels.length - 1);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget action(int index, {bool wrapped = false}) {
      final selected = index == selectedIndex;
      return Semantics(
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
            constraints: const BoxConstraints(
              minHeight: VSPDSAccessibility.minimumTapTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: VSPDSSpacing.xs,
              vertical: VSPDSSpacing.xs,
            ),
            decoration: wrapped && selected
                ? BoxDecoration(
                    color: VSPDSSemanticColors.accent,
                    borderRadius: BorderRadius.circular(VSPDSRadius.full),
                  )
                : null,
            child: Text(
              labels[index],
              textAlign: TextAlign.center,
              softWrap: true,
              style: (textStyle ?? VSPDSTypography.compactButton).copyWith(
                color: selected
                    ? VSPDSColors.black
                    : VSPDSSemanticColors.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final narrow = constraints.hasBoundedWidth && constraints.maxWidth < 420;
      final wrapActions = labels.length > 1 && (enlargedText || narrow);
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: VSPDSSemanticColors.surface,
          borderRadius: BorderRadius.circular(VSPDSRadius.full),
          border: Border.all(
            color: VSPDSSemanticColors.border,
            width: 0.5,
          ),
        ),
        child: wrapActions
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(labels.length, (index) {
                  final available = constraints.hasBoundedWidth
                      ? constraints.maxWidth - 6
                      : 320.0;
                  final columns = available >= 280 ? 2 : 1;
                  final width = (available - (columns - 1) * 8) / columns;
                  return SizedBox(
                    width: width.clamp(0.0, double.infinity).toDouble(),
                    child: action(index, wrapped: true),
                  );
                }),
              )
            : Stack(children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedAlign(
                      duration: reduceMotion
                          ? Duration.zero
                          : VSPDSMotion.segmentedSelection,
                      curve: Curves.easeInOut,
                      alignment: AlignmentDirectional(alignment, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / labels.length,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: VSPDSSemanticColors.accent,
                            borderRadius: BorderRadius.circular(VSPDSRadius.full),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(
                      labels.length,
                      (index) => Expanded(child: action(index)),
                    ),
                  ),
                ),
              ]),
      );
    });
  }
}
