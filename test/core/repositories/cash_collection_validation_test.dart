import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/cash_collection_validation.dart';

void main() {
  double? due(double total, double deposit, {
    String method = 'cash',
    String status = 'pending',
  }) => CashCollectionValidation.calculateDue(
        totalPrice: total,
        depositPaid: deposit,
        paymentMethod: method,
        paymentStatus: status,
      );

  test('cash receipt collects only the unpaid remainder', () {
    expect(due(400, 100), 300);
    expect(due(400, 0), 400);
    expect(due(400, 300), 100);
  });

  test('a fully paid deposit or inconsistent amount fails closed', () {
    expect(due(400, 400), 0.0); // Reconcile a full deposit, no cash owed.
    expect(due(400, 450), isNull);
    expect(due(400, -1), isNull);
    expect(due(0, 0), isNull);
    expect(due(double.nan, 0), isNull);
    expect(due(400, double.infinity), isNull);
  });

  test('online, refunded and settled bookings never accept cash again', () {
    expect(due(400, 0, method: 'paymob'), isNull);
    expect(due(400, 0, status: 'paid'), isNull);
    expect(due(400, 0, status: 'fully_paid'), isNull);
    expect(due(400, 0, status: 'refunded'), isNull);
    expect(due(400, 0, status: 'refund_pending'), isNull);
  });
}
