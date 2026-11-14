import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tournament repository routes direct RPCs through its client accessor', () {
    final source = File('lib/core/repositories/tournament_repository.dart')
        .readAsStringSync();

    expect(
      source,
      contains(
        'SupabaseClient get _supabase => _client ?? Supabase.instance.client;',
      ),
    );

    expect(source, isNot(contains('await Supabase.instance.client.rpc(')));

    for (final methodName in [
      'claimOwnerChampionshipApprovalHomeNotice',
      'getTournamentPaymentOrderStatus',
    ]) {
      final methodStart = source.indexOf(' $methodName(');
      expect(methodStart, greaterThanOrEqualTo(0), reason: methodName);

      final nextMethod = source.indexOf('\n  Future<', methodStart + 1);
      expect(nextMethod, greaterThan(methodStart), reason: methodName);

      final method = source.substring(methodStart, nextMethod);
      expect(
        method,
        contains('_supabase.rpc('),
        reason: '$methodName must use the repository client.',
      );
      expect(
        method,
        isNot(contains('await Supabase.instance.client.rpc(')),
        reason: '$methodName must not bypass dependency injection.',
      );
    }
  });
}
