import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';

/// Locally cached checkout drafts are private to the account that created them.
///
/// Legacy unscoped drafts are discarded: there is no safe way to attribute
/// those records to the current user after a logout/login or account switch.
class BookingDraftStorage {
  static const String _draftKey = 'vsp_draft_booking';
  static int _writeGeneration = 0;

  const BookingDraftStorage._();

  /// Read the authenticated account safely without requiring Supabase to
  /// be initialized by isolated tests or startup bootstrap.
  static String? currentAuthenticatedUserId() => _authUserId();

  static String? _authUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      // Supabase may not yet be initialized (e.g. during unit tests).
      return null;
    }
  }

  /// Persist only when an authenticated identity can be established.
  /// [userId] is an optional explicit scope for isolated unit tests.
  static Future<void> save(BookingDraft? draft, {String? userId}) async {
    final generation = ++_writeGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _writeGeneration) return;
      if (draft == null) {
        await prefs.remove(_draftKey);
        return;
      }
      final ownerUserId = userId ?? _authUserId();
      if (ownerUserId == null || ownerUserId.trim().isEmpty) {
        // Never leave an unscoped draft available for another account.
        await prefs.remove(_draftKey);
        return;
      }
      await prefs.setString(_draftKey, json.encode({
        'account_id': ownerUserId,
        'draft': draft.toMap(),
      }));
    } catch (_) {
      VSPLogger.w('Failed to persist booking draft (details redacted)');
    }
  }

  /// A draft may be restored only by the same authenticated account.
  static Future<BookingDraft?> restore({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final scope = userId ?? _authUserId();
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      final savedAccount = map['account_id'];
      final body = map['draft'];
      if (scope == null || scope.trim().isEmpty) {
        // An authenticated account might not be ready during startup.
        // Keep valid scoped data for later sign-in, but expose none of it.
        if (savedAccount is! String || body is! Map<String, dynamic>) {
          await prefs.remove(_draftKey);
        }
        return null;
      }
      if (savedAccount != scope || body is! Map<String, dynamic>) {
        // Reject both legacy unscoped records and another user's draft.
        await prefs.remove(_draftKey);
        return null;
      }

      final restored = BookingDraft.fromMap(body);
      if (restored.startTime.isAfter(
        DateTime.now().subtract(const Duration(minutes: 15)),
      )) {
        return restored;
      }
      await prefs.remove(_draftKey);
    } catch (_) {
      VSPLogger.w('Failed to restore booking draft (details redacted)');
    }
    return null;
  }

  static Future<void> clear() async {
    final generation = ++_writeGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _writeGeneration) return;
      await prefs.remove(_draftKey);
    } catch (_) {
      VSPLogger.w('Failed to clear booking draft (details redacted)');
    }
  }
}
