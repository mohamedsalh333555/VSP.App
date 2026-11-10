import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SEC-06: checkout status authorization is bound to owner id', () {
    final source = File(
      'supabase/functions/get_owner_web_checkout_status/handler.ts',
    ).readAsStringSync();

    // Prevent regression to an email-based ownership check. Checkout email
    // is supplied as contact information and is not an authorization identity.
    expect(
      source,
      contains('const isOrderOwner = order.owner_id === callerUser.id;'),
    );
    expect(
      source,
      isNot(contains('order.checkout_email.toLowerCase()')),
    );
    expect(source, contains('if (!isAdmin && !isOrderOwner)'));
    expect(source, isNot(contains('owner_id,checkout_email,status')));
    expect(source, contains('FORBIDDEN_NOT_ORDER_OWNER'));
    expect(
      source,
      matches(RegExp(r'sb\s*\.\s*auth\s*\.\s*getUser\s*\(\s*token\s*,?\s*\)')),
    );
  });

  test('SEC-06: deployed checkout entrypoints use request-tested handlers', () {
    for (final name in [
      'create_owner_web_checkout',
      'get_owner_web_checkout_status',
    ]) {
      final source = File('supabase/functions/$name/index.ts').readAsStringSync();
      expect(source, contains('import { createHandler } from "./handler.ts"'));
      expect(source, contains('serve(createHandler('));
    }
  });

  test('SEC-06: inquiry and signed subscription callback share strict payment validation', () {
    final inquiry = File(
      'supabase/functions/get_owner_web_checkout_status/handler.ts',
    ).readAsStringSync();
    final webhook = File(
      'supabase/functions/paymob_webhook/index.ts',
    ).readAsStringSync();
    expect(inquiry, contains('verifyOwnerSubscriptionPayment(tx, order)'));
    expect(webhook, contains('verifyOwnerSubscriptionPayment(obj, subscriptionOrder)'));
    // The signature rejection must precede subscription payment validation.
    expect(
      webhook.indexOf('if (!isHmacValid)'),
      lessThan(webhook.indexOf('verifyOwnerSubscriptionPayment(obj, subscriptionOrder)')),
    );
  });
}
