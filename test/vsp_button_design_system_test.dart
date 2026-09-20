import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/core/ui/components/vsp_button.dart';
import 'package:vsp_application/core/ui/components/vsp_badge.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

void main() {
  group('Design System & Tokens Tests', () {
    test('Verify VSPColors.warning is amber', () {
      expect(VSPColors.warning, const Color(0xFFF59E0B));
    });

    test('Verify VSPIconSize tokens hierarchy', () {
      expect(VSPIconSize.xs, 12.0);
      expect(VSPIconSize.sm, 16.0);
      expect(VSPIconSize.md, 20.0);
      expect(VSPIconSize.lg, 24.0);
      expect(VSPIconSize.xl, 32.0);
    });

    test('Verify VSPTypography buttonFontSize', () {
      expect(VSPTypography.buttonFontSize, 15.0);
      expect(VSPTypography.labelFontSize, 11.0);
    });

    test('Verify VSPBorder tokens', () {
      expect(VSPBorder.widthThin, 0.8);
      expect(VSPBorder.widthDefault, 1.0);
      expect(VSPBorder.widthMedium, 1.5);
      expect(VSPBorder.subtle().top.width, 0.8);
      expect(VSPBorder.accent().top.width, 1.0);
      expect(VSPBorder.light().top.width, 0.8);
    });

    testWidgets('VSPPrimaryButton renders with custom width, padding, and iconData', (tester) async {
      int pressCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VSPPrimaryButton(
                text: 'Click Me',
                width: 280,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                iconData: Icons.star,
                onPressed: () => pressCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Click Me'));
      expect(textWidget.style?.fontSize, VSPTypography.buttonFontSize);

      final container = tester.widget<Container>(find.byType(Container).first);
      final box = container.decoration as BoxDecoration?;
      expect(box?.borderRadius, BorderRadius.circular(VSPRadius.full));

      await tester.tap(find.text('Click Me'));
      await tester.pump();
      expect(pressCount, 1);

      // Second immediate tap is debounced
      await tester.tap(find.text('Click Me'), warnIfMissed: false);
      await tester.pump();
      expect(pressCount, 1);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.text('Click Me'));
      await tester.pump();
      expect(pressCount, 2);

      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('PrimaryButton facade forwards width, height, padding, and icon cleanly', (tester) async {
      int pressCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                text: 'Forwarded Button',
                width: 300,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                icon: Icons.check,
                onPressed: () => pressCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Forwarded Button'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(VSPPrimaryButton), findsOneWidget);

      final vspBtn = tester.widget<VSPPrimaryButton>(find.byType(VSPPrimaryButton));
      expect(vspBtn.width, 300);
      expect(vspBtn.height, 48);
      expect(vspBtn.padding, const EdgeInsets.symmetric(horizontal: 20));
      expect(vspBtn.iconData, Icons.check);

      await tester.tap(find.text('Forwarded Button'));
      await tester.pump();
      expect(pressCount, 1);

      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('VSPStatusBadge renders with warning variant and Amber color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: VSPStatusBadge(
                label: 'تحذير',
                variant: VSPBadgeVariant.warning,
                icon: Icons.warning_amber,
              ),
            ),
          ),
        ),
      );

      expect(find.text('تحذير'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.warning_amber));
      expect(iconWidget.size, VSPIconSize.xs);
      expect(iconWidget.color, VSPColors.warning);

      final textWidget = tester.widget<Text>(find.text('تحذير'));
      expect(textWidget.style?.fontSize, VSPTypography.labelFontSize);
      expect(textWidget.style?.color, VSPColors.warning);
    });
  });
}
