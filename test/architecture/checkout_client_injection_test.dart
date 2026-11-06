import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout cancellation uses injected Supabase client when supplied', () {
    final source = File(
      'lib/features/player/services/payment_checkout_coordinator.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('final SupabaseClient? _client;'),
    );
    expect(
      source,
      contains('await (_client ?? Supabase.instance.client).rpc('),
    );
    expect(
      source,
      isNot(contains("await Supabase.instance.client.rpc(\n            'cancel_tournament_payment_order_atomic'")),
    );
  });
}
