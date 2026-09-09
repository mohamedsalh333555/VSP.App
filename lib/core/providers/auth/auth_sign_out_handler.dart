import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'auth_draft_cleaner.dart';

/// Handles session sign-out lifecycle, clearing FCM tokens, drafts, and realtime listeners.
class AuthSignOutHandler {
  const AuthSignOutHandler._();

  /// Performs clean teardown of user session.
  static Future<void> performSignOut({
    required User? user,
    required String? userModelUid,
    required AuthService authService,
    required NotificationService notificationService,
    required VoidCallback onClearRealtime,
  }) async {
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': null})
            .eq('id', user.id);
      } catch (_) {}
    }

    await AuthDraftCleaner.clearSessionDrafts(user?.id ?? userModelUid);
    onClearRealtime();
    notificationService.stopRealtimeNotificationsListener();
    await authService.signOut();
  }
}
