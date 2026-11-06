import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tournament payment status respects repository client injection', () {
    final source = File('lib/core/repositories/tournament_repository.dart')
        .readAsStringSync();

    final methodStart = source.indexOf(
      'Future<Map<String, dynamic>> getTournamentPaymentOrderStatus(',
    );
    expect(methodStart, greaterThanOrEqualTo(0));

    final nextMethod = source.indexOf(
      '\n  Future<',
      methodStart + 1,
    );
    expect(nextMethod, greaterThan(methodStart));

    final method = source.substring(methodStart, nextMethod);
    expect(
      method,
      contains('(_client ?? Supabase.instance.client).rpc('),
      reason: 'Repository methods must respect the injected Supabase client.',
    );
    expect(
      method,
      isNot(contains('await Supabase.instance.client.rpc(')),
    );
  });
}
