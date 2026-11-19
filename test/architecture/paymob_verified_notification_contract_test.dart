import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Paymob webhook delegates booking receipt to verified SQL ledger', () {
    final webhook = File('supabase/functions/paymob_webhook/index.ts')
        .readAsStringSync();
    final ledger = webhook.indexOf('"record_booking_payment_atomic"');
    final returnReceipt = webhook.indexOf('type: "booking_payment"', ledger);
    final paymentBlock = webhook.substring(ledger, returnReceipt);
    expect(ledger, greaterThan(0));
    expect(paymentBlock, contains('paymentResult?.success !== true'));
    expect(paymentBlock, contains('paymentResult.idempotent === true'));
    expect(paymentBlock, isNot(contains('.from("notifications").insert(')));
  });

  test('verified payment trigger requires signed event and recorded ledger', () {
    final sql = File('supabase/migrations/'
      '20261117070000_paymob_verified_booking_payment_notification.sql')
        .readAsStringSync();
    expect(sql, contains('w.signature_verified=true'));
    expect(sql, contains("w.status='success'"));
    expect(sql, contains("t.status='completed'"));
    expect(sql, contains('v_tx.gross_amount*100'));
    expect(sql, contains('on conflict do nothing'));
    expect(sql, contains('new.user_id'));
    expect(sql, contains('s.owner_id'));
  });
}
