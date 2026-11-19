import '../../../../../core/ui/components/vsp_segmented_control.dart';
import 'package:flutter/material.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class CupsTabSelector extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabSelected;
  final String comingLabel;
  final String ongoingLabel;
  final String finishedLabel;

  const CupsTabSelector({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.comingLabel,
    required this.ongoingLabel,
    required this.finishedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.xs),
      child: VSPSegmentedControl(
        labels: [comingLabel, ongoingLabel, finishedLabel],
        selectedIndex: selectedTab,
        onSelected: onTabSelected,
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
