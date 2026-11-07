import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/vsp_quick_booking_receipt_formatter.dart';

void main() {
  final start = DateTime(2026, 11, 7, 18);
  final end = DateTime(2026, 11, 7, 19);

  String receipt({double total = 250.75, double deposit = 50.25, bool cash = false}) =>
      VSPQuickBookingReceiptFormatter.buildReceiptMessage(
        stadiumName: 'Pitch A',
        bookingRef: 'B001',
        customerName: 'Captain',
        startTime: start,
        endTime: end,
        totalPrice: total,
        depositPaid: deposit,
        isCashConfirmed: cash,
        isArabic: false,
      );

  test('receipt preserves fractional EGP amounts', () {
    final text = receipt();
    expect(text, contains('250.75 EGP'));
    expect(text, contains('50.25 EGP'));
    expect(text, contains('200.50 EGP'));
  });

  test('unconfirmed cash must not be described as collected', () {
    expect(receipt(deposit: 0), contains('Payment at pitch'));
    expect(receipt(deposit: 0), isNot(contains('Paid in full cash')));
  });

  test('deposit cannot exceed total in displayed receipt', () {
    final text = receipt(deposit: 1000);
    expect(text, contains('250.75 EGP'));
    expect(text, isNot(contains('1000.00 EGP')));
  });

  test('cash-confirmed receipt separates paid deposit from cash remainder', () {
    final text = receipt(cash: true);
    expect(text, contains('Cash: 200.50 EGP'));
  });
}
