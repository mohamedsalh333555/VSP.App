import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';

void main() {
  const ownerId = '10000000-0000-4000-8000-000000000001';
  const createdId = '20000000-0000-4000-8000-000000000001';

  Future<String?> addVenue({
    required Object? capacity,
    required List<String> requests,
    bool offline = false,
  }) async {
    final mock = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/rpc/check_owner_stadium_limit')) {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body)['p_owner_id'], ownerId);
        if (offline) throw const SocketException('offline_fixture');
        return http.Response(
          jsonEncode(capacity),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/stadiums')) {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body)['owner_id'], ownerId);
        return http.Response(
          jsonEncode({'id': createdId}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected stub route: ${request.url}');
    });
    final supabase = SupabaseClient(
      'https://fixture.invalid',
      'fixture_publishable_key_not_a_secret',
      httpClient: mock,
    );
    try {
      return await StadiumRepository(client: supabase).addStadium({
        'ownerId': ownerId,
        'name': 'Test Stadium',
        'features': <String, dynamic>{},
      });
    } finally {
      supabase.dispose();
    }
  }

  test('a verified available plan performs exactly one stadium insert', () async {
    final requests = <String>[];
    final id = await addVenue(
      capacity: {
        'allowed': true,
        'current_count': 0,
        'max_allowed': 1,
        'plan_code': 'basic',
      },
      requests: requests,
    );
    expect(id, createdId);
    expect(requests, hasLength(2));
    expect(requests.first, endsWith('/rpc/check_owner_stadium_limit'));
    expect(requests.last, endsWith('/stadiums'));
  });

  test('full free plan never reaches the stadium insert endpoint', () async {
    final requests = <String>[];
    await expectLater(
      addVenue(
        capacity: {
          'allowed': false,
          'current_count': 1,
          'max_allowed': 1,
          'plan_code': 'basic',
        },
        requests: requests,
      ),
      throwsA(isA<StateError>()),
    );
    expect(requests, hasLength(1));
    expect(requests.single, endsWith('/rpc/check_owner_stadium_limit'));
  });

  test('malformed or unauthorized RPC responses cannot create a venue', () async {
    for (final response in <Object?>[
      null,
      {'allowed': true},
      {'allowed': false, 'error': 'UNAUTHORIZED'},
    ]) {
      final requests = <String>[];
      final id = await addVenue(capacity: response, requests: requests);
      expect(id, isNull);
      expect(requests, hasLength(1));
    }
  });

  test('network failure must never fall through to insert', () async {
    final requests = <String>[];
    final id = await addVenue(
      capacity: null,
      requests: requests,
      offline: true,
    );
    expect(id, isNull);
    expect(requests, hasLength(1));
  });
}
