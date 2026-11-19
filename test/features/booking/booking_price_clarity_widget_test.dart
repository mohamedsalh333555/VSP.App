import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_bottom_bar.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Widget bookingTotalHost({
  required Locale locale,
  bool hasSlots = true,
  bool rentBall = true,
  double totalPrice = 107.75,
  double deposit = 0,
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BookingBottomBar(
            isOpenJoin: false,
            isPrivate: true,
            onPrivateChanged: (_) {},
            initialPlayersCount: 1,
            maxPlayersCount: 5,
            onPlayersCountChanged: (_) {},
            hasBallOption: true,
            isBallRented: rentBall,
            onBallRentedChanged: (_) {},
            ballPrice: 7.75,
            totalPrice: totalPrice,
            depositAmount: deposit,
            needsDeposit: deposit > 0,
            isSlotSelected: hasSlots,
            isLoading: false,
            onConfirmPressed: () {},
          ),
        ),
      ),
    );

void main() {
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    testWidgets('booking price shows exact selected total including optional ball for ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(bookingTotalHost(locale: locale));
      expect(find.textContaining('107.75'), findsOneWidget);
      expect(find.textContaining('7.75'), findsWidgets);
      expect(find.textContaining('107.8'), findsNothing);
      expect(find.textContaining('Booking total'), locale.languageCode == 'en'
          ? findsOneWidget : findsNothing);
      expect(find.textContaining('إجمالي الحجز'), locale.languageCode == 'ar'
          ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('stale total disappears when slot is deselected', (tester) async {
    await tester.pumpWidget(bookingTotalHost(
        locale: const Locale('en'), hasSlots: false, rentBall: true));
    expect(find.textContaining('107.75'), findsNothing);
    expect(find.textContaining('Select a booking slot first'), findsWidgets);
  });

  testWidgets('upfront deposit is disclosed next to full booking total',
      (tester) async {
    await tester.pumpWidget(bookingTotalHost(
      locale: const Locale('en'),
      deposit: 25.50,
    ));
    expect(find.textContaining('107.75'), findsOneWidget);
    expect(find.textContaining('Dep 25.5'), findsOneWidget);
  });

  test('the total includes the optional ball exactly once and is rechecked', () {
    final confirmation = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();
    expect(confirmation, contains('_selectedTimeSlots.length * _slotPrice'));
    expect(confirmation, contains(
      'if (_selectedTimeSlots.isNotEmpty && _isBallRented) total += _ballPrice;',
    ));
    expect(handler, contains('BookingPriceSnapshotGuard.matches('));
    expect(handler, contains('getStadiumByIdStrict(stadium.id)'));
    expect(handler, contains('displayedTotal: totalPrice'));
  });
}
