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
  bool get isOwner => true;

  @override
  bool get isPlayer => false;
}
