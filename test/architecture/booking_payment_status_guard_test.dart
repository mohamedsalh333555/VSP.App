import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment status updates both booking list and selected booking', () {
    final source = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<bool> updatePaymentStatus(');
    final end = source.indexOf('Future<bool> updateManualBooking(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final update = source.substring(start, end);
    expect(source, contains('final Set<String> _updatingPaymentIds = {};'));
    expect(update, contains('if (!_updatingPaymentIds.add(bookingId)) return false;'));
    expect(update, contains('_updatingPaymentIds.remove(bookingId)'));
    expect(update, contains('finally {'));
    expect(update, contains('BookingListModifier.updatePaymentStatus(_userBookings, bookingId, isPaid)'));
    expect(update, contains('if (_currentBooking?.id == bookingId)'));
    expect(update, contains('BookingListModifier.updatePaymentStatus(current, bookingId, isPaid)'));
    expect(update, contains('_currentBooking = current.single'));
    expect(update, contains('_repository.getBookingByIdStrict(bookingId)'));
    // UI must be notified before the best-effort refresh is awaited.
    expect(
      update.indexOf('notifyListeners();', update.indexOf('_currentBooking = current.single')),
      lessThan(update.indexOf('await _repository.getBookingByIdStrict(bookingId)')),
    );
    expect(update, contains('BookingListModifier.updateBooking(_userBookings, updated)'));
    expect(update, contains('_currentBooking = updated'));
    expect(update, contains('catch (_)'));
    expect(update, contains("debugPrint('Payment status refresh failed (details redacted)')"));
    expect(update, isNot(contains('refresh failed: \$refreshError')));
    expect(update, contains("_errorMessage = 'تعذر تحديث حالة الدفع'"));
    expect(update, contains('notifyListeners()'));
  });
}
