import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';

class BlockRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> blockUser({
    required String blockedUserId,
    String? reason,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || blockedUserId.isEmpty || uid == blockedUserId) {
      return false;
    }
    try {
      await _supabase.from('user_blocks').upsert(
        {
          'blocker_id': uid,
          'blocked_id': blockedUserId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
        onConflict: 'blocker_id,blocked_id',
      );
      return true;
    } catch (e) {
      VSPLogger.e('Error blocking user', e);
      return false;
    }
  }

  Future<bool> unblockUser(String blockedUserId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || blockedUserId.isEmpty) return false;
    try {
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', blockedUserId);
      return true;
    } catch (e) {
      VSPLogger.e('Error unblocking user', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _supabase
          .from('user_blocks')
          .select('id, blocked_id, reason, created_at')
          .eq('blocker_id', uid)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      VSPLogger.e('Error loading blocked users', e);
      return [];
    }
  }
}
