import 'package:shared_preferences/shared_preferences.dart';

/// Helper to purge local wizard and booking draft cache keys on user logout.
class AuthDraftCleaner {
  const AuthDraftCleaner._();

  /// Removes temp and user-scoped draft keys from shared preferences.
  static Future<void> clearSessionDrafts(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      for (final k in allKeys) {
        if (k.startsWith('temp_stadium_') ||
            k.startsWith('temp_tournament_') ||
            k == 'vsp_draft_booking' ||
            (uid != null &&
                uid.isNotEmpty &&
                (k.startsWith('vsp_draft_stadium_${uid}_') ||
                    k.startsWith('vsp_draft_tournament_${uid}_')))) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }
}
