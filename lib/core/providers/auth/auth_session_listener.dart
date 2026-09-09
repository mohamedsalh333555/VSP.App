import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/logger_service.dart';

/// Manages auth state changes stream subscription and web safe timeout.
class AuthSessionListener {
  const AuthSessionListener._();

  /// Starts listening to auth state stream and arms 5-second safe timeout.
  static StreamSubscription<User?> start({
    required AuthService authService,
    required bool Function() isInitializing,
    required VoidCallback onTimeout,
    required Future<void> Function(User?) onAuthStateChange,
  }) {
    Future.delayed(const Duration(seconds: 5), () {
      if (isInitializing()) {
        onTimeout();
        VSPLogger.w("Auth Safe-Timeout triggered: Supabase auth stream did not emit.");
      }
    });

    return authService.authStateChanges.listen((user) async {
      await onAuthStateChange(user);
    });
  }
}
