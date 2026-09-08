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
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(color: VSPColors.divider, width: 0.5),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: selectedTab == 0
                  ? AlignmentDirectional.centerStart
                  : (selectedTab == 1 ? AlignmentDirectional.center : AlignmentDirectional.centerEnd),
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: VSPColors.accent,
                    borderRadius: BorderRadius.circular(VSPRadius.full),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _buildTabButton(context, comingLabel, 0),
                _buildTabButton(context, ongoingLabel, 1),
                _buildTabButton(context, finishedLabel, 2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String text, int index) {
    final bool isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? Colors.black : VSPColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }
}
