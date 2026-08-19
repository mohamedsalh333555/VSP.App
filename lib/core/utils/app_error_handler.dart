import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ui/tokens/vsp_tokens.dart';

class AppErrorHandler {
  /// Converts raw exceptions to localized, user-friendly error messages.
  /// Handles Supabase PostgrestException error codes, network errors, and generic failures.
  static String getLocalizedMessage(BuildContext context, dynamic error) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final errString = error.toString().toLowerCase();

    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      final code = error.code ?? '';

      // ── Specific domain error codes from Supabase RPC / row-level checks ──
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
      } else if (msg.contains('dispute_window_expired')) {
        return isArabic
            ? 'انتهت المهلة الزمنية لتقديم النزاع (ساعة واحدة بعد نهاية المباراة).'
            : 'The dispute window has expired (1 hour after match end).';
      } else if (msg.contains('not_at_stadium')) {
        return isArabic
            ? 'فشل النزاع: أنت لست متواجداً في محيط الملعب حالياً.'
            : 'Dispute failed: You are not near the stadium.';
      }

      // ── PostgreSQL error codes ──
      if (code == '42703' || msg.contains('column') && msg.contains('does not exist')) {
        // undefined_column: DB schema mismatch — never expose raw message to user
        return isArabic
            ? 'حدث خطأ في قاعدة البيانات. يرجى التواصل مع الدعم الفني.'
            : 'A database configuration error occurred. Please contact support.';
      } else if (code == '23505' || msg.contains('duplicate key') || msg.contains('unique constraint')) {
        return isArabic
            ? 'هذا السجل موجود بالفعل في النظام.'
            : 'This record already exists.';
      } else if (code == '23503' || msg.contains('foreign key')) {
        return isArabic
            ? 'عملية غير صالحة: مرجع البيانات غير موجود.'
            : 'Invalid operation: referenced data does not exist.';
      } else if (code == 'PGRST301' || msg.contains('jwt expired') || msg.contains('unauthorized')) {
        return isArabic
            ? 'انتهت فترة الجلسة. يرجى تسجيل الدخول مجدداً.'
            : 'Session expired. Please log in again.';
      } else if (code == 'PGRST116' || msg.contains('json object requested, multiple') ) {
        // Multiple rows returned where single expected
        return isArabic
            ? 'حدث خطأ في استرجاع البيانات.'
            : 'An error occurred while retrieving data.';
      }

      // ── HTTP status codes returned by PostgREST ──
      final httpStatus = error.details?.toString() ?? '';
      if (httpStatus.contains('400') || httpStatus.contains('Bad Request')) {
        return isArabic
            ? 'طلب غير صالح. يرجى التحقق من البيانات المدخلة.'
            : 'Invalid request. Please check your input data.';
      } else if (httpStatus.contains('403') || httpStatus.contains('Forbidden')) {
        return isArabic
            ? 'ليس لديك صلاحية لتنفيذ هذه العملية.'
            : 'You do not have permission to perform this action.';
      } else if (httpStatus.contains('500')) {
        return isArabic
            ? 'خطأ في الخادم. يرجى المحاولة لاحقاً.'
            : 'Server error. Please try again later.';
      }
    }

    // ── Network / connectivity errors ──
    if (errString.contains('network') ||
        errString.contains('socketexception') ||
        errString.contains('connection refused') ||
        errString.contains('timeout') ||
        errString.contains('handshake')) {
      return isArabic
          ? 'تعذر الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت.'
          : 'Network connection error. Please check your internet connection.';
    }

    if (errString.contains('double booking') || errString.contains('time_conflict')) {
      return isArabic
          ? 'عذراً، هذا الوقت تم حجزه للتو من لاعب آخر.'
          : 'Sorry, this time slot has just been booked by another player.';
    }

    // ── Default clean fallback — never expose raw database/stack details ──
    return isArabic
        ? 'حدث خطأ أثناء تنفيذ العملية. يرجى المحاولة لاحقاً.'
        : 'An error occurred while processing your request. Please try again later.';
  }

  /// Displays a standardized error SnackBar (red styling).
  static void showError(BuildContext context, dynamic error) {
    if (!context.mounted) return;
    final message = getLocalizedMessage(context, error);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Iconsax.warning_2_copy, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: VSPColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
        ),
      );
  }

  /// Displays a standardized success SnackBar (green styling).
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Iconsax.tick_circle_copy, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: VSPColors.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
        ),
      );
  }

  /// Displays an error SnackBar with a "Retry" action button.
  static void showRetry(
    BuildContext context,
    dynamic error, {
    required VoidCallback onRetry,
    String? retryLabel,
  }) {
    if (!context.mounted) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final message = getLocalizedMessage(context, error);
    final label = retryLabel ?? (isArabic ? 'إعادة المحاولة' : 'Retry');

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Iconsax.warning_2_copy, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: label,
            textColor: Colors.white,
            onPressed: onRetry,
          ),
          backgroundColor: VSPColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
        ),
      );
  }
}
