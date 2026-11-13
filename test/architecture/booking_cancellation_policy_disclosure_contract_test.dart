import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pre-confirmation UI discloses current cancellation policy in both languages', () {
    final screen = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    final note = File(
      'lib/features/player/widgets/booking/booking_cancellation_policy_note.dart',
    ).readAsStringSync();

    expect(screen, contains('const BookingCancellationPolicyNote()'));
    expect(screen.indexOf('const BookingCancellationPolicyNote()'),
        lessThan(screen.indexOf('bottomNavigationBar: BookingBottomBar(')));
    expect(note, contains('ExpansionTile('));
    expect(note, contains('سياسة إلغاء الحجز'));
    expect(note, contains('Booking cancellation policy'));
    expect(note, contains('6 ساعات'));
    expect(note, contains('20 دقيقة'));
    expect(note, contains('within 6 hours'));
    expect(note, contains('first 20 minutes'));
    expect(note, contains('يحدد الخادم أهلية الإلغاء والاسترداد'));
    expect(note, contains('The server determines cancellation and refund eligibility'));
  });
}
