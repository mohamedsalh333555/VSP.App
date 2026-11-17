import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refund API ID alone never proves completed refund', () {
    final source = File('supabase/functions/paymob_webhook/index.ts')
        .readAsStringSync();
    expect(source, isNot(contains(
      'refundData.success === true || refundData.is_refund === true || refundData.id',
    )));
    expect(source, contains(
      'refundRes.ok && (refundData.success === true || refundData.is_refund === true)',
    ));
    expect(source, contains('refundAccounting?.success !== true'));
    expect(source, contains('refundSuccess = false;'));
    expect(source, contains('.eq("status", "cancelled")'));
  });

  test('successful refund message follows server ledger acceptance', () {
    final source = File('supabase/functions/paymob_webhook/index.ts')
        .readAsStringSync();
    final refunded = source.indexOf('if (obj.is_refunded === true)');
    final accounting = source.indexOf('"record_booking_gateway_refund_atomic"', refunded);
    final guard = source.indexOf('refundResult?.success !== true', accounting);
    final message = source.indexOf('title: "تم اعتماد الاسترداد المالي!', guard);
    expect(refunded, greaterThan(0));
    expect(accounting, greaterThan(refunded));
    expect(guard, greaterThan(accounting));
    expect(message, greaterThan(guard));
  });
}
