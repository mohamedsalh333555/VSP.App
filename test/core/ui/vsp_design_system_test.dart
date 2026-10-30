import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/components/vsp_button.dart';
import 'package:vsp_application/core/ui/tokens/vsp_design_tokens.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/shared/widgets/vsp_back_button.dart';

void main() {
  group('VSP Design System V2', () {
    test('legacy visual tokens resolve to the canonical V2 values', () {
      expect(VSPColors.background, VSPDSSemanticColors.background);
      expect(VSPColors.accent, VSPDSSemanticColors.accent);
      expect(VSPRadius.card, VSPDSRadius.card);
      expect(VSPSize.buttonHeight, VSPDSizes.buttonHeight);
      expect(VSPSpacing.md, VSPDSSpacing.sm);
      expect(VSPStates.disabledOpacity, VSPDSOpacity.disabled);
    });

    testWidgets('canonical primary button invokes its action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: VSPPrimaryButton(
                  text: 'Continue',
                  onPressed: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('back button exposes the canonical minimum touch target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VSPBackButton(onTap: () {}),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(VSPBackButton)),
        const Size(
          VSPDSAccessibility.minimumTapTarget,
          VSPDSAccessibility.minimumTapTarget,
        ),
      );
    });
  });
}
