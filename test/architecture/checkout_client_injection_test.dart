import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout cancellation respects an injected Supabase client', () {
    final source = File(
      'lib/features/player/services/payment_checkout_coordinator.dart',
    ).readAsStringSync();

    expect(source, contains('final SupabaseClient? _client;'));
    expect(
      source,
      contains('SupabaseClient? client'),
      reason: 'Tests must be able to supply a scoped Supabase client.',
    );
    expect(source, contains('_client = client;'));

    final methodStart = source.indexOf('Future<void> releaseBookingSafely(');
    final nextMethod = source.indexOf('\n  Future<', methodStart + 1);
    expect(methodStart, greaterThanOrEqualTo(0));
    expect(nextMethod, greaterThan(methodStart));

    final method = source.substring(methodStart, nextMethod);
    expect(method, contains("'cancel_tournament_payment_order_atomic'"));
    expect(method, contains('(_client ?? Supabase.instance.client).rpc('));
    expect(method, isNot(contains('await Supabase.instance.client.rpc(')));
  });
}
