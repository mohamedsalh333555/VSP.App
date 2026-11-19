import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking bar separates final booking total from required deposit', () {
    final bar = File(
      'lib/features/player/widgets/booking/booking_bottom_bar.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/player/widgets/booking/booking_financial_summary.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();

    final stadiumBar = File(
      'lib/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart',
    ).readAsStringSync();

    // Deposit is shown only for finite, positive amounts. An invalid
    // mandatory deposit must not be relabeled as a cash/no-deposit offer.
    expect(stadiumBar, contains('stadium.depositAmount.isFinite && stadium.depositAmount > 0.0'));
    expect(stadiumBar, contains('final unverifiedDeposit = stadium.needsDeposit && !hasDeposit;'));
    expect(stadiumBar, contains("'Deposit amount unavailable'"));
    expect(stadiumBar, contains("'No deposit required'"));
    // Defense in depth: this button must reject invalid money even if a
    // parent widget incorrectly passes bookingEnabled: true.
    expect(stadiumBar, contains('final financialInputsValid = stadium.basePrice.isFinite'));
    expect(stadiumBar, contains('onPressed: bookingEnabled && financialInputsValid'));
    expect(bar, contains("isArabic ? 'إجمالي الحجز' : 'Booking total'"));
    expect(bar, isNot(contains("isArabic ? 'المبلغ المطلوب' : 'Amount due'")));
    // A stale price cannot be displayed when the selected time slots vanish.
    expect(bar, contains('isSlotSelected ? totalPrice : 0.0'));
    expect(bar, contains('VSPMoneyFormatter.amount(displayTotalPrice)'));
    expect(bar, contains('VSPMoneyFormatter.amount(depositAmount)'));
    expect(summary, contains('عربون الحجز المطلوب'));
    expect(summary, contains('Upfront Deposit Required'));
    expect(summary, contains('المتبقي عند الملعب'));
    expect(summary, contains('Remaining at Pitch'));
    // A negative remainder must never be represented as a valid 0 EGP balance.
    // Instead, the owner-deposit mismatch is disclosed for correction.
    expect(summary, contains('Review price and deposit'));
    expect(summary, contains('deposit > totalPrice'));
    expect(summary, contains('VSPMoneyFormatter.amount(totalPrice - deposit)'));
    expect(summary, isNot(contains('(totalPrice - deposit).clamp(0, double.infinity)')));
    expect(screen, contains('_selectedTimeSlots.length * _slotPrice'));
    expect(screen, contains('if (_selectedTimeSlots.isNotEmpty && _isBallRented) total += _ballPrice;'));
  });
}
