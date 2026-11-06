import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tournament coordinators route RPCs through scoped clients', () {
    final repository = File('lib/core/repositories/tournament_repository.dart')
        .readAsStringSync();
    for (final coordinator in [
      'TournamentQueryCoordinator',
      'TournamentLifecycleCoordinator',
      'TournamentStatsCoordinator',
      'TournamentRosterCoordinator',
      'TournamentRegistrationCoordinator',
      'TournamentMatchCoordinator',
      'TournamentFixtureCoordinator',
    ]) {
      expect(
        RegExp('$coordinator' r'\\s*\\(\\s*client:\\s*_client').hasMatch(repository),
        isTrue,
        reason: coordinator,
      );
    }

    for (final name in [
      'tournament_registration_coordinator',
      'tournament_lifecycle_coordinator',
      'tournament_match_coordinator',
      'tournament_query_coordinator',
      'tournament_roster_coordinator',
      'tournament_fixture_coordinator',
      'tournament_stats_coordinator',
    ]) {
      final path = 'lib/core/repositories/tournament/$name.dart';
      final source = File(path).readAsStringSync();

      expect(
        source,
        contains('SupabaseClient get _supabase => _client ?? Supabase.instance.client;'),
        reason: path,
      );
      expect(
        source,
        contains('_supabase.rpc('),
        reason: '$path should use the scoped client for RPC calls.',
      );
      expect(
        source,
        isNot(contains('await Supabase.instance.client.rpc(')),
        reason: '$path must not bypass dependency injection.',
      );
    }
  });
}
