import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';

class ReportRepository {
  final SupabaseClient _supabase;

  ReportRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  Future<bool> reportEntity({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
    String? details,
    String? contextType,
    String? contextId,
    String? bookingId,
    String? conversationId,
  }) async {
    final cleanReporterId = reporterId.trim();
    final cleanTargetId = targetId.trim();
    final cleanTargetType = targetType.trim().toLowerCase();
    final cleanReason = reason.trim();
    final cleanDetails = details?.trim();
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != cleanReporterId) return false;
    if (cleanTargetId.isEmpty ||
        !{'user', 'booking', 'match'}.contains(cleanTargetType) ||
        cleanReason.isEmpty ||
        cleanReason.length > 200 ||
        (cleanDetails?.length ?? 0) > 2000) {
      return false;
    }
    try {
      await _supabase.rpc('create_report_atomic', params: {
        'p_target_type': cleanTargetType,
        'p_target_id': cleanTargetId,
        'p_reason': cleanReason,
        'p_details': cleanDetails?.isEmpty == true ? null : cleanDetails,
        'p_context_type': contextType,
        'p_context_id': contextId,
        'p_booking_id': bookingId,
        'p_conversation_id': conversationId,
      });
      return true;
    } catch (e) {
      VSPLogger.e('Report submission failed');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getReportsStream() {
    return _supabase.from('reports').stream(primaryKey: ['id']).map((list) {
      final sorted = List<Map<String, dynamic>>.from(list);
      sorted.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return sorted;
    }).handleError((e) {
      VSPLogger.w('Handled realtime error in getReportsStream: $e');
    });
  }
}
