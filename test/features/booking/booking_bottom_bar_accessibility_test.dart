import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_bottom_bar.dart';

void main() {
  Widget host({
    required Locale locale,
    required bool hasSlot,
    bool isBallRented = false,
    bool isLoading = false,
    bool openJoin = false,
    int count = 1,
    ValueChanged<bool>? onBallChanged,
    ValueChanged<int>? onCountChanged,
  }) {
    return MaterialApp(
      locale: locale,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BookingBottomBar(
            isOpenJoin: openJoin,
            isPrivate: true,
            onPrivateChanged: (_) {},
            initialPlayersCount: count,
            maxPlayersCount: 5,
            onPlayersCountChanged: onCountChanged ?? (_) {},
            hasBallOption: true,
            isBallRented: isBallRented,
            onBallRentedChanged: onBallChanged ?? (_) {},
            ballPrice: 50,
            totalPrice: 250,
            depositAmount: 0,
            needsDeposit: false,
            isSlotSelected: hasSlot,
            isLoading: isLoading,
            onConfirmPressed: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('ball rental is announced but disabled without a chosen slot', (tester) async {
    final semantics = tester.ensureSemantics();
    var toggles = 0;
    await tester.pumpWidget(host(
      locale: const Locale('en'),
      hasSlot: false,
      isBallRented: true,
      onBallChanged: (_) => toggles++,
    ));

    final control = find.bySemanticsLabel(RegExp(r'Ball rental, 50 EGP'));
    expect(control, findsOneWidget);
    final props = tester.widget<Semantics>(control).properties;
    expect(props.button, isTrue);
    expect(props.enabled, isFalse);
    expect(props.toggled, isFalse);
    await tester.tap(control);
    expect(toggles, 0);
    semantics.dispose();
  });

  testWidgets('Arabic ball rental exposes toggled state and action with selected slot', (tester) async {
    final semantics = tester.ensureSemantics();
    bool? lastValue;
    await tester.pumpWidget(host(
      locale: const Locale('ar'),
      hasSlot: true,
      isBallRented: true,
      onBallChanged: (value) => lastValue = value,
    ));

    final control = find.bySemanticsLabel(RegExp(r'إيجار كرة، 50 جنيه'));
    expect(control, findsOneWidget);
    final props = tester.widget<Semantics>(control).properties;
    expect(props.enabled, isTrue);
    expect(props.toggled, isTrue);
    await tester.tap(control);
    expect(lastValue, isFalse);
    semantics.dispose();
  });

  testWidgets('player count buttons are labeled and respect bounds', (tester) async {
    final semantics = tester.ensureSemantics();
    int? changed;
    await tester.pumpWidget(host(
      locale: const Locale('en'),
      hasSlot: true,
      openJoin: true,
      count: 1,
      onCountChanged: (value) => changed = value,
    ));
    final decrease = find.byTooltip('Decrease player count');
    final increase = find.byTooltip('Increase player count');
    expect(decrease, findsOneWidget);
    expect(increase, findsOneWidget);
    expect(tester.widget<IconButton>(decrease).onPressed, isNull);
    expect(find.bySemanticsLabel('Player count: 1'), findsOneWidget);
    await tester.tap(increase);
    expect(changed, 2);
    semantics.dispose();
  });
}
