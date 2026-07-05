import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';

class ReportRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Support old constructor to avoid compile error in DatabaseService
  ReportRepository({dynamic firestore});

  Future<bool> reportEntity({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
    String? details,
  }) async {
    try {
      await _supabase.from('reports').insert({
        'reporter_id': reporterId,
        'target_id': targetId,
        'target_type': targetType,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      VSPLogger.e('Error reporting entity on Supabase', e);
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getReportsStream() {
    return _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .map((list) {
          final sorted = List<Map<String, dynamic>>.from(list);
          sorted.sort((a, b) {
            final dateA = DateTime.parse(a['created_at'].toString());
            final dateB = DateTime.parse(b['created_at'].toString());
            return dateB.compareTo(dateA);
          });
          return sorted;
        });
  }
}
