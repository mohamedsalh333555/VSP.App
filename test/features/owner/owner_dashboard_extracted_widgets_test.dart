import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/dashboard/owner_pro_segmented_tabs.dart';

void main() {
  group('OwnerProSegmentedTabs Widget Tests', () {
    testWidgets('renders Overview and Insights tabs with correct localized labels', (tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnerProSegmentedTabs(
              selectedIndex: selected,
              onTabSelected: (val) => selected = val,
              isArabic: true,
            ),
          ),
        ),
      );

      expect(find.text('نظرة عامة'), findsOneWidget);
      expect(find.text('التحليلات'), findsOneWidget);

      await tester.tap(find.text('التحليلات'));
      await tester.pumpAndSettle();

      expect(selected, equals(1));
    });

    testWidgets('renders English labels when isArabic is false', (tester) async {
      int selected = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnerProSegmentedTabs(
              selectedIndex: selected,
              onTabSelected: (val) => selected = val,
              isArabic: false,
            ),
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);

      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      expect(selected, equals(0));
    });
  });
}
