import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/shared/widgets/vsp_back_button.dart';

void main() {
  group('VSPBackButton Widget Tests', () {
    testWidgets('renders arrow_right_3_copy in RTL directionality', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                leading: const VSPBackButton(),
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Iconsax.arrow_right_3_copy,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('renders arrow_left_2_copy in LTR directionality', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              appBar: AppBar(
                leading: const VSPBackButton(),
              ),
            ),
          ),
        ),
      );

      final iconFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Iconsax.arrow_left_2_copy,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('triggers custom onTap callback when tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                leading: VSPBackButton(
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(VSPBackButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('pops the current route when tapped with default onPressed', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => Scaffold(
                          appBar: AppBar(leading: const VSPBackButton()),
                          body: const Text('Second Screen'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Page'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open second screen
      await tester.tap(find.text('Open Page'));
      await tester.pumpAndSettle();
      expect(find.text('Second Screen'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byType(VSPBackButton));
      await tester.pumpAndSettle();

      // Should be back on the first screen
      expect(find.text('Second Screen'), findsNothing);
      expect(find.text('Open Page'), findsOneWidget);
    });
  });
}
