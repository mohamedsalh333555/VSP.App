import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/auth/social_auth_service.dart';
import 'package:vsp_application/core/services/auth_service.dart';

void main() {
  group('SocialAuthService Tests', () {
    test('instantiates safely with lazy client', () {
      final service = SocialAuthService();
      expect(service, isNotNull);
    });

    test('SignInWithOAuthOptions builds correctly with parameters', () {
      const options = SignInWithOAuthOptions(
        redirectTo: 'io.supabase.fluttervsp://callback',
        queryParams: {'prompt': 'select_account'},
        data: {'role': 'player'},
      );

      expect(options.redirectTo, equals('io.supabase.fluttervsp://callback'));
      expect(options.queryParams?['prompt'], equals('select_account'));
      expect(options.data?['role'], equals('player'));
    });
  });

  group('AuthService Social Auth Delegation Tests', () {
    test('instantiates with custom SocialAuthService delegate safely', () {
      final socialAuth = SocialAuthService();
      final authService = AuthService(socialAuthService: socialAuth);
      expect(authService, isNotNull);
    });
  });
}
