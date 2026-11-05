import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class RealHttpOverrides extends HttpOverrides {}

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _runLiveTests =
    bool.fromEnvironment('VSP_RUN_LIVE_TESTS', defaultValue: false);
const _canRunLiveTests =
    _runLiveTests && _supabaseUrl != '' && _supabaseAnonKey != '';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  group(
    'VSP staging public and anonymous security contract',
    () {
      late SupabaseClient client;

      setUpAll(() {
        client = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      });

      test('email signup is enabled but requires confirmation', () async {
        final response = await http.get(
          Uri.parse('$_supabaseUrl/auth/v1/settings'),
          headers: {'apikey': _supabaseAnonKey},
        );
        expect(response.statusCode, 200);

        final settings =
            jsonDecode(response.body) as Map<String, dynamic>;
        final external =
            settings['external'] as Map<String, dynamic>? ?? const {};
        expect(external['email'], isTrue);
        expect(settings['disable_signup'], isFalse);
        expect(settings['mailer_autoconfirm'], isFalse);
      });

      test('anonymous stadium discovery exposes approved venues only', () async {
        final rows = await client
            .from('stadiums')
            .select(
              'id, is_verified, is_blocked, is_deleted_by_owner',
            )
            .limit(100);

        for (final row in rows) {
          expect(row['is_verified'], isTrue);
          expect(row['is_blocked'], isFalse);
          expect(row['is_deleted_by_owner'], isFalse);
        }
      });

      test('required public app configuration is present', () async {
        final config = await client
            .from('app_config')
            .select('id,is_maintenance,min_version,vsp_1v1_is_open')
            .eq('id', 1)
            .maybeSingle();

        expect(config, isNotNull);
        expect(config!['id'], 1);
        expect(config['is_maintenance'], isA<bool>());
        expect(config['min_version'], isA<String>());
        expect(config['vsp_1v1_is_open'], isA<bool>());
      });

      test('anonymous users cannot enumerate user rows', () async {
        final rows = await client.from('users').select('id').limit(1);
        expect(rows, isEmpty);
      });

      test('team directory requires authentication', () async {
        await expectLater(
          client.from('teams_public').select('id, name').limit(1),
          throwsA(
            isA<PostgrestException>().having(
              (error) => error.code,
              'code',
              '42501',
            ),
          ),
        );
      });

      test('subscription plan catalog is publicly readable', () async {
        final rows = await client
            .from('public_subscription_plans')
            .select()
            .limit(10);
        expect(rows, isA<List<dynamic>>());
      });

      test('anonymous caller cannot execute admin approval', () async {
        await expectLater(
          client.rpc(
            'admin_approve_owner_atomic',
            params: {
              'p_owner_id': '00000000-0000-0000-0000-000000000001',
            },
          ),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('anonymous caller cannot execute admin metrics', () async {
        await expectLater(
          client.rpc('get_admin_metrics'),
          throwsA(isA<PostgrestException>()),
        );
      });
    },
    skip: !_canRunLiveTests
        ? 'Requires explicit VSP_RUN_LIVE_TESTS=true and staging credentials.'
        : false,
  );
}
