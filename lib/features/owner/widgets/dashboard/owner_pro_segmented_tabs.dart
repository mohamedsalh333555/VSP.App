import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Pill segmented switcher for Pro Owners: Overview vs Insights
class OwnerProSegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool isArabic;

  const OwnerProSegmentedTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            alignment: selectedIndex == 0
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
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
              _buildTabButton(
                title: isArabic ? 'نظرة عامة' : 'Overview',
                index: 0,
              ),
              _buildTabButton(
                title: isArabic ? 'التحليلات' : 'Insights',
                index: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String title, required int index}) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTabSelected(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.black : VSPColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
