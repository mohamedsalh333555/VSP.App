import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/services/auth_service.dart';

class TestOwnerAuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
}

class TestOwnerAuthProvider extends AuthProvider {
  TestOwnerAuthProvider() : super(authService: TestOwnerAuthService());

  @override
  User? get currentUser => User.fromJson({
        'id': 'test-owner-user',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'owner@test.invalid',
        'created_at': '2026-01-01T00:00:00.000Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      });

  @override
  bool get isOwner => true;

  @override
  bool get isPlayer => false;
}
