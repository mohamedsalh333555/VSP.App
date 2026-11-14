import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/repositories/team_repository.dart';

void main() {
  test('loads every membership and returns deterministic team ordering',
      () async {
    const userId = '10000000-0000-4000-8000-000000000001';
    const teamA = '20000000-0000-4000-8000-000000000001';
    const teamB = '20000000-0000-4000-8000-000000000002';
    final requestedTeamIds = <String>[];

    final mock = MockClient((request) async {
      final select = request.url.queryParameters['select'] ?? '';
      if (request.url.path.endsWith('/team_members') &&
          select == 'team_id') {
        expect(request.url.queryParameters['user_id'], 'eq.$userId');
        // Deliberately reverse the IDs to prove no PostgREST row order leaks.
        return http.Response(
          jsonEncode([
            {'team_id': teamB},
            {'team_id': teamA},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (request.url.path.endsWith('/teams_public')) {
        final filter = request.url.queryParameters['id'];
        final teamId = filter?.replaceFirst('eq.', '');
        if (teamId == null) throw StateError('Missing team identity filter');
        requestedTeamIds.add(teamId);
        return http.Response(
          jsonEncode([
            {
              'id': teamId,
              'name': teamId == teamA ? 'Zamalek Juniors' : 'Aswan Stars',
              'captain_id': userId,
              'governorate': 'Aswan',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (request.url.path.endsWith('/team_members') &&
          select == 'user_id') {
        expect(request.url.queryParameters['team_id'], isNotNull);
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      throw StateError('Unexpected membership fixture request: ${request.url}');
    });
    final supabase = SupabaseClient(
      'https://fixture.invalid',
      'fixture_publishable_key_not_a_secret',
      httpClient: mock,
    );
    try {
      final teams = await TeamRepository(client: supabase)
          .getUserTeamsStrict(userId);
      expect(requestedTeamIds, [teamA, teamB]);
      expect(teams.map((team) => team.id), [teamB, teamA]);
      expect(teams.map((team) => team.name), [
        'Aswan Stars',
        'Zamalek Juniors',
      ]);
    } finally {
      supabase.dispose();
    }
  });

  test('no memberships does not request or invent a team', () async {
    const userId = '10000000-0000-4000-8000-000000000001';
    var requestCount = 0;
    final mock = MockClient((request) async {
      requestCount++;
      expect(request.url.path, endsWith('/team_members'));
      expect(request.url.queryParameters['user_id'], 'eq.$userId');
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final supabase = SupabaseClient(
      'https://fixture.invalid',
      'fixture_publishable_key_not_a_secret',
      httpClient: mock,
    );
    try {
      final teams = await TeamRepository(client: supabase)
          .getUserTeamsStrict(userId);
      expect(teams, isEmpty);
      expect(requestCount, 1);
    } finally {
      supabase.dispose();
    }
  });
}
