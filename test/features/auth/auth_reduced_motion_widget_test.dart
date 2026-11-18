import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/shared/widgets/vsp_fade_in_item.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';
import 'package:vsp_application/shared/widgets/custom_text_field.dart';
import 'package:vsp_application/shared/widgets/vsp_terms_checkbox.dart';

Widget host(Widget child, {required bool reduced}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('staggered content appears immediately without animation when reduced',
      (tester) async {
    await tester.pumpWidget(host(
      const VSPFadeInItem(index: 10, child: Text('Important action')),
      reduced: true,
    ));
    expect(find.text('Important action'), findsOneWidget);
    expect(find.descendant(of: find.byType(VSPFadeInItem),
        matching: find.byType(FadeTransition)), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal setting retains normal staggered visual transition',
      (tester) async {
    await tester.pumpWidget(host(
      const VSPFadeInItem(index: 0, child: Text('Important action')),
      reduced: false,
    ));
    expect(find.descendant(of: find.byType(VSPFadeInItem),
        matching: find.byType(FadeTransition)), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion can be enabled mid-transition and content remains visible',
      (tester) async {
    Widget contents(bool disabled) => host(
          const VSPFadeInItem(index: 9, child: Text('Persistent content')),
          reduced: disabled,
        );
    await tester.pumpWidget(contents(false));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(contents(true));
    expect(find.text('Persistent content'), findsOneWidget);
    expect(find.descendant(of: find.byType(VSPFadeInItem),
        matching: find.byType(FadeTransition)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline success indicator switches instantly with reduced motion',
      (tester) async {
    final ctrl = TextEditingController();
    await tester.pumpWidget(host(
      CustomTextField(controller: ctrl, keyboardType: TextInputType.emailAddress),
      reduced: true,
    ));
    await tester.enterText(find.byType(TextFormField), 'player@example.com');
    await tester.pump();
    final transition = tester.widget<AnimatedSwitcher>(
      find.descendant(of: find.byType(CustomTextField),
          matching: find.byType(AnimatedSwitcher)),
    );
    expect(transition.duration, Duration.zero);
    await tester.pumpWidget(const SizedBox.shrink());
    ctrl.dispose();
  });

  testWidgets('terms check visual change is instant when reduced but still toggles',
      (tester) async {
    bool checked = false;
    await tester.pumpWidget(host(
      VSPTermsCheckbox(value: checked, onChanged: (value) => checked = value),
      reduced: true,
    ));
    final animated = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(animated.duration, Duration.zero);
    await tester.tap(find.byType(AnimatedContainer));
    await tester.pump();
    expect(checked, isTrue);
  });

  testWidgets('animated button never scales with reduced motion, but still accepts tap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      VSPAnimatedButton(text: 'Continue', cooldownMs: 1, onPressed: () => taps++),
      reduced: true,
    ));
    final scale = tester.widget<ScaleTransition>(
      find.descendant(of: find.byType(VSPAnimatedButton),
          matching: find.byType(ScaleTransition)),
    );
    expect(scale.scale.value, 1.0);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
