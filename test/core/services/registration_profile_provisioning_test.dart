import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/auth/auth_user_data_fetcher.dart';
import 'package:vsp_application/core/repositories/user_repository.dart';

class ProvisionProfiles extends UserRepository {
  final List<Map<String, dynamic>?> profiles;
  bool roleResult = false;
  bool updateResult = false;
  int reads = 0;
  int roleCalls = 0;
  int updates = 0;
  ProvisionProfiles(this.profiles);
  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final index = reads++;
    final value = profiles[index < profiles.length ? index : profiles.length - 1];
    return value == null ? null : Map<String, dynamic>.from(value);
  }
  @override
  Future<bool> setUserRole(String userId, String role) async {
    roleCalls++;
    return roleResult;
  }
  @override
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> data,
      {User? authUser, String? role}) async {
    updates++;
    return updateResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final user = User.fromJson({
    'id': 'provision-test-user', 'aud': 'authenticated', 'role': 'authenticated',
    'email': 'test@example.invalid', 'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{},
  })!;
  Map<String, dynamic> profile({String role = 'owner', bool complete = false, String? phone}) => {
    'id': user.id, 'email': user.email, 'role': role, 'name': 'Synthetic',
    'is_registration_complete': complete, 'is_email_verified': false,
    if (phone != null) 'phone': phone,
  };
  setUp(() {
    SharedPreferences.setMockInitialValues({'pending_oauth_role': 'owner'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureChannel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureChannel, null);
  });

  for (final payload in [null, <String, dynamic>{}, {'success': false},
    {'success': 'true'}, <dynamic>[], {'success': true}]) {
    test('provisioning trusts only confirmed server profile: ${jsonEncode(payload)}', () async {
      var requests = 0;
      final confirmed = payload is Map && payload['success'] == true;
      final repo = ProvisionProfiles([null, null, null, confirmed ? profile() : null]);
      final client = SupabaseClient('https://staging.invalid', 'fake-public-key',
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.path, '/rest/v1/rpc/provision_registration_profile');
          expect(jsonDecode(request.body), {'p_role': 'owner'});
          return http.Response(jsonEncode(payload), 200, request: request,
            headers: {'content-type': 'application/json'});
        }));
      addTearDown(client.dispose);
      final result = await AuthUserDataFetcher(client: client, userRepository: repo)
        .fetch(user: user, currentUserType: 'owner');
      expect(requests, 1);
      expect(result.dataFetchError, !confirmed);
      expect(result.userModel?.uid, confirmed ? user.id : null);
      expect(result.userModel?.isRegistrationComplete, confirmed ? false : null);
    });
  }
  test('network failure cannot manufacture a local profile', () async {
    final client = SupabaseClient('https://staging.invalid', 'fake-public-key',
      httpClient: MockClient((_) async => throw http.ClientException('private-detail')));
    addTearDown(client.dispose);
    final result = await AuthUserDataFetcher(client: client,
      userRepository: ProvisionProfiles([null])).fetch(user: user, currentUserType: 'owner');
    expect(result.dataFetchError, true);
    expect(result.userModel, null);
  });
  test('success without a readable persisted profile fails closed', () async {
    final client = SupabaseClient('https://staging.invalid', 'fake-public-key',
      httpClient: MockClient((request) async => http.Response('{"success":true}', 200,
        request: request, headers: {'content-type': 'application/json'})));
    addTearDown(client.dispose);
    final result = await AuthUserDataFetcher(client: client,
      userRepository: ProvisionProfiles([null])).fetch(user: user, currentUserType: 'owner');
    expect(result.dataFetchError, true);
    expect(result.userModel, null);
  });
  test('privileged pending role rejected before any repository or network access', () async {
    SharedPreferences.setMockInitialValues({'pending_oauth_role': 'admin'});
    final repo = ProvisionProfiles([profile()]);
    final result = await AuthUserDataFetcher(userRepository: repo)
      .fetch(user: user, currentUserType: null);
    expect(result.dataFetchError, true);
    expect(repo.reads, 0);
  });
  for (final accepted in [false, true]) {
    test('role override requires both acceptance and authoritative reread: $accepted', () async {
      final repo = ProvisionProfiles([profile(role: 'player')])..roleResult = accepted;
      final result = await AuthUserDataFetcher(userRepository: repo)
        .fetch(user: user, currentUserType: 'owner');
      expect(result.dataFetchError, true);
      expect(result.userModel, null);
      expect(repo.roleCalls, 1);
    });
  }
  for (final updated in [false, true]) {
    test('phone cannot grant local completion when server remains incomplete: $updated', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ProvisionProfiles([profile(role: 'player', phone: '01000000001')])
        ..updateResult = updated;
      final result = await AuthUserDataFetcher(userRepository: repo)
        .fetch(user: user, currentUserType: null);
      expect(result.dataFetchError, false);
      expect(result.userModel?.isRegistrationComplete, false);
      expect(repo.updates, 1);
    });
  }
  test('login-only missing account cannot provision a profile', () async {
    SharedPreferences.setMockInitialValues({
      'pending_oauth_role': 'owner', 'pending_oauth_is_login_only': true,
    });
    final result = await AuthUserDataFetcher(userRepository: ProvisionProfiles([null]))
      .fetch(user: user, currentUserType: 'owner');
    expect(result.dataFetchError, true);
    expect(result.userModel, null);
  });
}
