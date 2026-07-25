import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ui/tokens/vsp_tokens.dart';

class AppErrorHandler {
  /// Converts raw exceptions to localized, user-friendly error messages
  static String getLocalizedMessage(BuildContext context, dynamic error) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final errString = error.toString().toLowerCase();

    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('double_booking') || msg.contains('time_conflict')) {
        return isArabic
            ? 'عذراً، هذا الوقت تم حجزه للتو من لاعب آخر.'
            : 'Sorry, this time slot has just been booked by another player.';
      } else if (msg.contains('match_is_full')) {
        return isArabic
            ? 'عذراً، هذه المباراة اكتمل عدد لاعبيها بالفعل.'
            : 'Sorry, this match is already full.';
      } else if (msg.contains('already_joined')) {
        return isArabic
            ? 'أنت بالفعل ضمن المشاركين في هذه المباراة.'
            : 'You are already a participant in this match.';
      } else if (msg.contains('jwt expired') || msg.contains('unauthorized')) {
        return isArabic
            ? 'انتهت فترة الجلسة. يرجى إعادة التسجيل.'
            : 'Session expired. Please log in again.';
      }
    }

    if (errString.contains('network') || errString.contains('socketexception') || errString.contains('timeout')) {
      return isArabic
          ? 'تعذر الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت.'
          : 'Network connection error. Please check your internet connection.';
    }

    if (errString.contains('double booking') || errString.contains('time_conflict')) {
      return isArabic
          ? 'عذراً، هذا الوقت تم حجزه للتو من لاعب آخر.'
          : 'Sorry, this time slot has just been booked by another player.';
    }

    // Default clean fallback without raw database/stack details
    return isArabic
        ? 'حدث خطأ أثناء تنفيذ العملية. يرجى المحاولة لاحقاً.'
        : 'An error occurred while processing your request. Please try again later.';
  }

  /// Displays a standardized SnackBar with error styling
  static void showError(BuildContext context, dynamic error) {
    if (!context.mounted) return;
    final message = getLocalizedMessage(context, error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: VSPColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
      ),
    );
  }
}
