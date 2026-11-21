import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/shared/widgets/vsp_position_selector.dart';

void main() {
  testWidgets('football positions wrap on narrow devices and remain selectable', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          child: VSPPositionSelector(
            selectedPosition: selected,
            onPositionSelected: (value) => selected = value,
          ),
        ),
      ),
    ));
    final firstWidth = tester.getSize(find.text('Goalkeeper')).width;
    expect(firstWidth, greaterThan(0));
    expect(find.text('Goalkeeper'), findsOneWidget);
    expect(find.text('Defender'), findsOneWidget);
    expect(find.text('Midfielder'), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);
    await tester.tap(find.text('Goalkeeper'));
    expect(selected, 'GK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('very narrow selector uses a single column', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 140,
          child: VSPPositionSelector(
            selectedPosition: 'GK',
            onPositionSelected: (_) {},
          ),
        ),
      ),
    ));
    final goalkeeper = tester.getTopLeft(find.text('Goalkeeper'));
    final defender = tester.getTopLeft(find.text('Defender'));
    expect(defender.dy, greaterThan(goalkeeper.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('position selector honors disableAnimations', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: VSPPositionSelector(
          selectedPosition: 'FW',
          onPositionSelected: (_) {},
        )),
      ),
    ));
    final animations = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(animations, isNotEmpty);
    expect(animations.every((widget) => widget.duration == Duration.zero), isTrue);
  });
}
