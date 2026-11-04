import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ui/components/vsp_segmented_control.dart';

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
    return VSPSegmentedControl(
      labels: [isArabic ? 'نظرة عامة' : 'Overview', isArabic ? 'التحليلات' : 'Insights'],
      selectedIndex: selectedIndex,
      onSelected: (index) {
        HapticFeedback.selectionClick();
        onTabSelected(index);
      },
    );
  }
}
