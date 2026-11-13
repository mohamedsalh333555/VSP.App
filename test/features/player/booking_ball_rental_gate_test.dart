import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_bottom_bar.dart';

void main() {
  Widget bar({
    required bool hasSelectedSlot,
    required bool isBallRented,
    required double totalPrice,
    required ValueChanged<bool> onBallRentedChanged,
    required VoidCallback onConfirmPressed,
  }) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BookingBottomBar(
          isOpenJoin: false,
          isPrivate: true,
          onPrivateChanged: (_) {},
          initialPlayersCount: 1,
          maxPlayersCount: 10,
          onPlayersCountChanged: (_) {},
          hasBallOption: true,
          isBallRented: isBallRented,
          onBallRentedChanged: onBallRentedChanged,
          ballPrice: 30.0,
          totalPrice: totalPrice,
          depositAmount: 50,
          needsDeposit: false,
          isSlotSelected: hasSelectedSlot,
          isLoading: false,
          onConfirmPressed: onConfirmPressed,
        ),
      ),
    );
  }

  testWidgets('no active slot: ball option does not toggle and old price is hidden',
      (tester) async {
    var toggleCalls = 0;
    var confirmCalls = 0;
    await tester.pumpWidget(bar(
      hasSelectedSlot: false,
      // Simulate stale state during a selected-date change.
      isBallRented: true,
      totalPrice: 230,
      onBallRentedChanged: (_) => toggleCalls++,
      onConfirmPressed: () => confirmCalls++,
    ));

    expect(find.textContaining('Select a booking slot first'), findsOneWidget);
    expect(find.textContaining('0 EGP'), findsWidgets);
    expect(find.textContaining('230 EGP'), findsNothing);
    await tester.tap(find.textContaining('Ball /'));
    await tester.pump();
    expect(toggleCalls, 0);
    expect(confirmCalls, 0);
  });

  testWidgets('valid slot: user can opt into ball rental and total updates',
      (tester) async {
    var selected = false;
    var toggles = 0;
    await tester.pumpWidget(bar(
      hasSelectedSlot: true,
      isBallRented: selected,
      totalPrice: 200,
      onBallRentedChanged: (value) {
        toggles++;
        selected = value;
      },
      onConfirmPressed: () {},
    ));
    expect(find.textContaining('200 EGP'), findsOneWidget);
    await tester.tap(find.textContaining('Ball /'));
    await tester.pump();
    expect(selected, isTrue);
    expect(toggles, 1);
    await tester.pumpWidget(bar(
      hasSelectedSlot: true,
      isBallRented: selected,
      totalPrice: 230,
      onBallRentedChanged: (value) => selected = value,
      onConfirmPressed: () {},
    ));
    expect(find.textContaining('230 EGP'), findsOneWidget);
  });
}
