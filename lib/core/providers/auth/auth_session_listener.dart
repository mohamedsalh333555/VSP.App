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
    final timeout = Timer(const Duration(seconds: 5), () {
      if (isInitializing()) {
        onTimeout();
        VSPLogger.w("Auth Safe-Timeout triggered: Supabase auth stream did not emit.");
      }
    });
    final controller = StreamController<User?>();
    StreamSubscription<User?>? sourceSubscription;

    controller.onListen = () {
      sourceSubscription = authService.authStateChanges.listen(
        (user) {
          timeout.cancel();
          controller.add(user);
        },
        onError: controller.addError,
        onDone: () {
          timeout.cancel();
          controller.close();
        },
      );
    };
    controller.onCancel = () async {
      timeout.cancel();
      await sourceSubscription?.cancel();
    };

    return controller.stream.listen((user) async {
      await onAuthStateChange(user);
    });
  }
}
