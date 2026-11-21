import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collective booking does not advertise cash payment or deposit', () {
    final summary = File('lib/features/player/widgets/booking/booking_financial_summary.dart').readAsStringSync();
    final screen = File('lib/features/player/screens/booking_confirmation_screen.dart').readAsStringSync();
    expect(screen, contains('isOpenJoin: _isOpenJoin'));
    expect(summary, contains('Collective bookings require full online payment'));
    expect(summary, contains('if (isOpenJoin) {'));
  });

  test('location-conditional payments are not promised as cash, and invalid remainder is disclosed', () {
    final source = File('lib/features/player/widgets/booking/booking_financial_summary.dart').readAsStringSync();
    expect(source, isNot(contains('100% Cash at the pitch')));
    expect(source, isNot(contains('restore your rating')));
    expect(source, contains('Payment methods depend on location and booking rules'));
    expect(source, contains('Review price and deposit'));
    expect(source, isNot(contains('(totalPrice - deposit).clamp(0, double.infinity)')));
  });
}
