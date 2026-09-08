import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';

/// Handles persistence and restoration of the current active booking draft across app restarts.
class BookingDraftStorage {
  static const String _draftKey = 'vsp_draft_booking';

  const BookingDraftStorage._();

  /// Persists current active booking draft to SharedPreferences.
  static Future<void> save(BookingDraft? draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (draft != null) {
        final jsonStr = json.encode(draft.toMap());
        await prefs.setString(_draftKey, jsonStr);
      } else {
        await prefs.remove(_draftKey);
      }
    } catch (e) {
      VSPLogger.w('Failed to persist booking draft: $e');
    }
  }

  /// Restores active booking draft from local storage if within the valid time window.
  static Future<BookingDraft?> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        final restored = BookingDraft.fromMap(map);
        // Only restore if start time is still in future or within 15 min grace period
        if (restored.startTime.isAfter(DateTime.now().subtract(const Duration(minutes: 15)))) {
          return restored;
        } else {
          await prefs.remove(_draftKey);
        }
      }
    } catch (e) {
      VSPLogger.w('Failed to restore booking draft: $e');
    }
    return null;
  }

  /// Clears active booking draft from storage.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      VSPLogger.w('Failed to clear booking draft: $e');
    }
  }
}
