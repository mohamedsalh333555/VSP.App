import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('known governorate stays in the server query with visibility guards', () async {
    final requests = <Uri>[];
    final client = SupabaseClient(
      'https://fixture.invalid',
      'fixture_publishable_key_not_a_secret',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/stadiums');
        return http.Response(
          jsonEncode([{'id': 'stadium-aswan', 'name': 'Aswan Pitch',
            'governorate': 'Aswan', 'is_verified': true, 'is_blocked': false,
            'is_deleted_by_owner': false}]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = StadiumRepository(client: client);
    final result = await repository.getStadiumsPaginated(governorate: 'Aswan');
    expect(requests, hasLength(1));
    final params = requests.single.queryParameters;
    expect(params['is_verified'], 'eq.true');
    expect(params['is_blocked'], 'eq.false');
    expect(params['is_deleted_by_owner'], 'eq.false');
    expect(params['or'], contains('governorate.eq.Aswan'));
    expect(result['items'], hasLength(1));
    expect(result['lastDoc'], 1);
  });

  test('unknown explicit governorate cannot turn into nationwide results', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://fixture.invalid',
      'fixture_publishable_key_not_a_secret',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('[]', 200, request: request,
            headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(client.dispose);
    final result = await StadiumRepository(client: client).getStadiumsPaginated(
      governorate: 'Unknown place',
    );
    expect(result['items'], isEmpty);
    expect(result['lastDoc'], 0);
    expect(requests, 0);
  });
}
