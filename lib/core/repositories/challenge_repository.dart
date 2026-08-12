import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/vsp_feedback.dart';

class ChallengeResult {
  final String id;
  final String challengeId;
  final int team1Score;
  final int team2Score;
  final String submittedBy;
  final String? confirmedBy;
  final String status; // 'pending', 'confirmed', 'disputed'
  final DateTime createdAt;
  final DateTime? confirmedAt;

  ChallengeResult({
    required this.id,
    required this.challengeId,
    required this.team1Score,
    required this.team2Score,
    required this.submittedBy,
    this.confirmedBy,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
  });

  bool get isConfirmed => status == 'confirmed' && confirmedBy != null;

  factory ChallengeResult.fromMap(Map<String, dynamic> map, String id) {
    return ChallengeResult(
      id: id,
      challengeId: map['challenge_id']?.toString() ?? '',
      team1Score: map['team1_score'] ?? 0,
      team2Score: map['team2_score'] ?? 0,
      submittedBy: map['submitted_by']?.toString() ?? '',
      confirmedBy: map['confirmed_by']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      confirmedAt: map['confirmed_at'] != null ? DateTime.parse(map['confirmed_at']) : null,
    );
  }
}

class ChallengeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// ⚽ 1. Submit match result for dual approval
  Future<bool> submitChallengeResult(
    BuildContext context, {
    required String challengeId,
    required int team1Score,
    required int team2Score,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return false;

    try {
      await _supabase.from('challenge_results').insert({
        'challenge_id': challengeId,
        'team1_score': team1Score,
        'team2_score': team2Score,
        'submitted_by': currentUser.id,
        'confirmed_by': null,
        'status': 'pending',
      });

      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          "تم إرسال نتيجة التحدي! تنتظر تأكيد القائد الآخر ⏳",
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error: $e');
      if (context.mounted) {
        VSPFeedback.showError(context, "فشل إرسال النتيجة. يرجى المحاولة لاحقاً.");
      }
      return false;
    }
  }

  /// 🤝 2. Dual Confirmation or Dispute by Counter Captain
  Future<bool> confirmChallengeResult(
    BuildContext context, {
    required String resultId,
    required bool approve,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return false;

    try {
      if (approve) {
        await _supabase.from('challenge_results').update({
          'confirmed_by': currentUser.id,
          'confirmed_at': DateTime.now().toIso8601String(),
          'status': 'confirmed',
        }).eq('id', resultId);

        // 🚀 Invoke server Edge Function / RPC for safe Elo calculation
        try {
          await _supabase.functions.invoke('calculate_elo_update', body: {'result_id': resultId});
        } catch (err) {
          debugPrint('RPC Elo calculation notice: $err');
        }

        if (context.mounted) {
          VSPFeedback.showSuccess(context, "تم تأكيد النتيجة وتحديث نقاط الترتيب! ✅");
        }
      } else {
        await _supabase.from('challenge_results').update({
          'status': 'disputed',
        }).eq('id', resultId);

        if (context.mounted) {
          VSPFeedback.showInfo(context, "تم تسجيل النزاع. سيقوم الإدمن بمراجعة النتيجة.");
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error confirming challenge result: $e');
      if (context.mounted) {
        VSPFeedback.showError(context, "حدث خطأ أثناء معالجة التأكيد.");
      }
      return false;
    }
  }
}

