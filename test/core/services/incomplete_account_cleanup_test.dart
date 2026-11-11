import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/providers/auth/auth_registration_service.dart';
import 'package:vsp_application/core/services/auth_service.dart';

class CleanupFallback extends AuthService {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> deleteAccount(String uid) async { calls++; return {'success': false}; }
}

void main() {
  final user = User.fromJson({
    'id': 'test-incomplete-user', 'aud': 'authenticated', 'role': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{},
  });
  for (final payload in [null, <String, dynamic>{}, {'success': false}, {'success': 'true'}, {'success': true}]) {
    test('incomplete cleanup handles ${jsonEncode(payload)} without extra destructive retries', () async {
      final fallback = CleanupFallback();
      var rpcCalls = 0;
      final client = SupabaseClient('https://staging.invalid', 'fake-public-key', httpClient: MockClient((request) async {
        rpcCalls++;
        expect(request.url.path, '/rest/v1/rpc/delete_user_permanently');
        expect(jsonDecode(request.body), {'p_user_id': user.id});
        return http.Response(jsonEncode(payload), 200, request: request, headers: {'content-type': 'application/json'});
      }));
      addTearDown(client.dispose);
      await AuthRegistrationService(client: client, authService: fallback).abortRegistration(user, null);
      expect(rpcCalls, 1); expect(fallback.calls, 0);
    });
  }
  test('completed account is never purged when aborting onboarding', () async {
    var requests = 0;
    final client = SupabaseClient('https://staging.invalid', 'fake-public-key', httpClient: MockClient((request) async {
      requests++; return http.Response('{}', 200, request: request);
    }));
    addTearDown(client.dispose);
    await AuthRegistrationService(client: client).abortRegistration(user, UserModel(
      uid: user.id, email: 'test@example.invalid', role: 'player', isRegistrationComplete: true,
    ));
    expect(requests, 0);
  });
}
