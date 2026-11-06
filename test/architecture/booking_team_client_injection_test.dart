import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking and team repositories keep RPCs on injected clients', () {
    for (final path in [
      'lib/core/repositories/booking_repository.dart',
      'lib/core/repositories/team_repository.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('SupabaseClient get _supabase => _client ?? Supabase.instance.client;'),
        reason: path,
      );
      expect(
        source,
        isNot(contains('await Supabase.instance.client.rpc(')),
        reason: '$path must not bypass its injected client.',
      );
      expect(
        source,
        contains('_supabase.rpc('),
        reason: '$path must route its RPCs through the shared accessor.',
      );
    }
  });
}
