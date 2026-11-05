import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SEC-06: checkout status authorization is bound to owner id', () {
    final source = File(
      'supabase/functions/get_owner_web_checkout_status/index.ts',
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
    expect(source, contains('if (!isAdmin && !isOrderOwner)'));\n    expect(source, isNot(contains('owner_id,checkout_email,status')));
    expect(source, contains('FORBIDDEN_NOT_ORDER_OWNER'));
    expect(source, contains('sb.auth.getUser(token)'));
  });
}
