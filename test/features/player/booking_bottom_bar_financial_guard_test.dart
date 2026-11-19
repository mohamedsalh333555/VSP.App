import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_bottom_bar.dart';

Widget bookingBar({
  bool selected = true,
  bool loading = false,
  bool collective = false,
  double total = 200,
  double deposit = 50,
  bool needsDeposit = true,
  double ballPrice = 30,
  bool rentBall = false,
  VoidCallback? onConfirm,
}) =>
    MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BookingBottomBar(
          isOpenJoin: collective,
          isPrivate: true,
          onPrivateChanged: (_) {},
          initialPlayersCount: 1,
          maxPlayersCount: 10,
          onPlayersCountChanged: (_) {},
          hasBallOption: true,
          isBallRented: rentBall,
          onBallRentedChanged: (_) {},
          ballPrice: ballPrice,
          totalPrice: total,
          depositAmount: deposit,
          needsDeposit: needsDeposit,
          isSlotSelected: selected,
          isLoading: loading,
          onConfirmPressed: onConfirm ?? () {},
        ),
      ),
    );

ElevatedButton confirmation(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

void main() {
  testWidgets('invalid total or mandatory deposit cannot confirm a booking',
      (tester) async {
    final cases = <Map<String, double>>[
      {'total': 0},
      {'total': -1},
      {'total': double.nan},
      {'total': double.infinity},
      {'deposit': 0},
      {'deposit': -1},
      {'deposit': double.nan},
      {'deposit': double.infinity},
      {'deposit': 250},
    ];
    for (final bad in cases) {
      await tester.pumpWidget(bookingBar(
        total: bad['total'] ?? 200,
        deposit: bad['deposit'] ?? 50,
      ));
      await tester.pump();
      expect(confirmation(tester).onPressed, isNull, reason: '$bad');
      expect(find.text('Review booking price'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('invalid selected ball rental quote cannot confirm a booking',
      (tester) async {
    for (final ballPrice in [-1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(bookingBar(rentBall: true, ballPrice: ballPrice));
      await tester.pump();
      expect(confirmation(tester).onPressed, isNull);
      expect(find.text('Review booking price'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('valid quote still confirms, but loading or no slot cannot',
      (tester) async {
    var confirms = 0;
    await tester.pumpWidget(bookingBar(onConfirm: () => confirms++));
    expect(confirmation(tester).onPressed, isNotNull);
    await tester.tap(find.text('Booking Confirmation'));
    expect(confirms, 1);

    await tester.pumpWidget(bookingBar(selected: false));
    expect(confirmation(tester).onPressed, isNull);
    expect(find.text('Select Time'), findsOneWidget);

    await tester.pumpWidget(bookingBar(loading: true));
    expect(confirmation(tester).onPressed, isNull);
  });

  testWidgets('collective full payment does not depend on optional cash deposit',
      (tester) async {
    await tester.pumpWidget(bookingBar(
      collective: true, deposit: double.nan, needsDeposit: true));
    expect(confirmation(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
