import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/providers/auth/auth_profile_service.dart';
import 'package:vsp_application/core/services/auth_service.dart';

class RecordingAuthService extends AuthService {
  RecordingAuthService(SupabaseClient client) : super(client: client);
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SupabaseClient clientFor(
    Object? rpcResponse, {
    int rpcStatus = 200,
    bool failBookingLookup = false,
  }) {
    final client = SupabaseClient(
      'https://staging.invalid',
      'fake-public-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/delete_user_permanently')) {
          expect(jsonDecode(request.body), {'p_user_id': 'test-user'});
          return http.Response(
            jsonEncode(rpcResponse),
            rpcStatus,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (failBookingLookup) {
          throw StateError('sentinel-secret-email@example.invalid');
        }
        expect(
          request.url.path,
          anyOf('/rest/v1/bookings', '/rest/v1/stadiums'),
        );
        return http.Response('[]', 200, headers: {
          'content-type': 'application/json',
        }, request: request);
      }),
    );
    addTearDown(client.dispose);
    return client;
  }

  const unconfirmed = <Object?>[
    null,
    <String, Object?>{},
    <String, Object?>{'success': false, 'message': 'sentinel-secret'},
    <String, Object?>{'success': 'true'},
    <String, Object?>{'success': 1},
    <Object?>[],
    true,
  ];

  for (var i = 0; i < unconfirmed.length; i++) {
    test('auth service keeps account session on unconfirmed deletion $i', () async {
      final auth = RecordingAuthService(clientFor(unconfirmed[i]));
      final result = await auth.deleteAccount('test-user');
      expect(result['success'], isFalse);
      expect(auth.signOutCalls, 0);
      expect(result.toString(), isNot(contains('sentinel-secret')));
    });

    for (final role in ['player', 'owner']) {
      test('$role profile never reports unconfirmed deletion $i as success', () async {
        final service = AuthProfileService(client: clientFor(unconfirmed[i]));
        final result = await service.deleteAccount(UserModel(
          uid: 'test-user', email: 'test@example.invalid', role: role,
        ));
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, isNot(contains('sentinel-secret')));
      });
    }
  }

  test('auth service signs out only after explicit deletion confirmation', () async {
    final auth = RecordingAuthService(clientFor({'success': true}));
    final result = await auth.deleteAccount('test-user');
    expect(result['success'], isTrue);
    expect(auth.signOutCalls, 1);
  });

  for (final role in ['player', 'owner']) {
    test('$role profile accepts explicit deletion confirmation', () async {
      final service = AuthProfileService(client: clientFor({'success': true}));
      final result = await service.deleteAccount(UserModel(
        uid: 'test-user', email: 'test@example.invalid', role: role,
      ));
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });
  }

  test('deletion backend exception does not leak response or secret to logs', () async {
    final logs = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = oldDebugPrint);
    final auth = RecordingAuthService(clientFor({
      'message': 'sentinel-secret-email@example.invalid',
      'code': 'TEST_ERROR',
    }, rpcStatus: 500));
    final result = await auth.deleteAccount('test-user');
    expect(result['success'], isFalse);
    expect(auth.signOutCalls, 0);
    expect(result.toString(), isNot(contains('sentinel-secret')));
    expect(logs.join(), isNot(contains('sentinel-secret')));
  });

  test('failed booking precheck does not expose backend error to user', () async {
    final service = AuthProfileService(
      client: clientFor({'success': true}, failBookingLookup: true),
    );
    final result = await service.deleteAccount(UserModel(
      uid: 'test-user', email: 'test@example.invalid', role: 'player',
    ));
    expect(result.success, isFalse);
    expect(result.error, isNot(contains('sentinel-secret')));
  });
}
