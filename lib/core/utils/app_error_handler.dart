import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ui/tokens/vsp_tokens.dart';

class AppErrorHandler {
  /// Converts raw exceptions to localized, user-friendly error messages.
  /// Handles Supabase PostgrestException error codes, network errors, and generic failures.
  static String getLocalizedMessage(BuildContext context, dynamic error) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return formatError(error, isArabic: isArabic);
  }

  /// Converts raw exceptions or error objects to standardized, user-friendly error messages.
  /// Centralized SSOT for error translation across domain, repository, and UI layers (H-05).
  static String formatError(dynamic error, {bool isArabic = true}) {
    if (error == null) {
      return isArabic
          ? 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.'
          : 'An unexpected error occurred. Please try again.';
    }

    String message = '';
    String code = '';
    String details = '';

    if (error is PostgrestException) {
      message = error.message;
      code = error.code ?? '';
      details = error.details?.toString() ?? '';
    } else {
      message = error.toString();
    }

    final combined = '$code $message $details'.toLowerCase();

    // ── Domain Business Rule Codes ──
    if (combined.contains('slot_locked_or_taken') ||
        combined.contains('slot already booked') ||
        combined.contains('double_booking') ||
        combined.contains('time_conflict') ||
        combined.contains('هذا الوقت محجوز') ||
        combined.contains('تحجز نفس الوقت')) {
      return isArabic
          ? 'الوقت المحدد محجوز بالفعل، يرجى اختيار موعد آخر.'
          : 'This time slot is already booked. Please choose another.';
    }

    if (combined.contains('stadium_limit_exceeded') ||
        combined.contains('الحد الأقصى للملاعب') ||
        combined.contains('stadium limit exceeded')) {
      return isArabic
          ? 'تم تجاوز الحد الأقصى للملاعب المسموح بها في باقتك.'
          : 'You have exceeded the maximum number of stadiums allowed for your plan.';
    }

    if (combined.contains('cannot_confirm_cancelled_booking') ||
        combined.contains('حجز ملغي')) {
      return isArabic
          ? 'لا يمكن تحصيل حجز ملغي.'
          : 'Cannot collect payment for a cancelled booking.';
    }

    if (combined.contains('no_show') || combined.contains('تكرار عدم الحضور')) {
      return isArabic
          ? 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.'
          : 'Your account is restricted from cash bookings due to repeated no-shows. Please pay online.';
    }

    if (combined.contains('حجز نقدي نشط') ||
        combined.contains('cash limit') ||
        combined.contains('حد الكاش')) {
      return isArabic
          ? 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.'
          : 'You already have an active cash booking. Please complete it first or pay online.';
    }

    if (combined.contains('active_bookings_exist')) {
      return isArabic
          ? 'لا يمكن حذف الملعب لوجود مباريات وحجوزات نشطة جارية أو قادمة.'
          : 'Cannot delete pitch because active matches or bookings exist.';
    }

    if (combined.contains('انتهت صلاحية باقة الاشتراك') ||
        combined.contains('subscription_expired')) {
      return isArabic
          ? 'انتهت صلاحية باقة الاشتراك الخاصة بك. يرجى تجديد الاشتراك للمتابعة.'
          : 'Your subscription plan has expired. Please renew to continue.';
    }

    if (combined.contains('trial_start_failed')) {
      return isArabic
          ? 'تعذر تفعيل التجربة المجانية. ربما تم استخدامها من قبل.'
          : 'Unable to activate the free trial. It may have already been used.';
    }

    if (combined.contains('subscription_order_failed')) {
      return isArabic
          ? 'تعذر إنشاء طلب الاشتراك. يرجى المحاولة لاحقاً.'
          : 'Unable to create the subscription order. Please try again later.';
    }

    if (combined.contains('checkout_url_missing') ||
        combined.contains('paymob_launch_failed')) {
      return isArabic
          ? 'تعذر فتح صفحة الدفع. يرجى المحاولة مرة أخرى.'
          : 'Unable to open the payment page. Please try again.';
    }

    if (combined.contains('support_contact_not_configured')) {
      return isArabic
          ? 'بيانات تصعيد الدعم غير مُهيأة حالياً.'
          : 'Support escalation contact is not configured.';
    }

    if (combined.contains('match_is_full') ||
        combined.contains('match is full')) {
      return isArabic
          ? 'عذراً، هذه المباراة اكتمل عدد لاعبيها بالفعل.'
          : 'Sorry, this match is already full.';
    }

    if (combined.contains('already_joined')) {
      return isArabic
          ? 'أنت بالفعل ضمن المشاركين في هذه المباراة.'
          : 'You are already a participant in this match.';
    }

    if (combined.contains('dispute_window_expired')) {
      return isArabic
          ? 'انتهت المهلة الزمنية لتقديم النزاع (ساعة واحدة بعد نهاية المباراة).'
          : 'The dispute window has expired (1 hour after match end).';
    }

    if (combined.contains('not_at_stadium')) {
      return isArabic
          ? 'فشل النزاع: أنت لست متواجداً في محيط الملعب حالياً.'
          : 'Dispute failed: You are not near the stadium.';
    }

    // ── PostgreSQL error codes ──
    if (code == '42703' || combined.contains('column') && combined.contains('does not exist')) {
      return isArabic
          ? 'حدث خطأ في قاعدة البيانات. يرجى التواصل مع الدعم الفني.'
          : 'A database configuration error occurred. Please contact support.';
    } else if (code == '23505' || combined.contains('duplicate key') || combined.contains('unique constraint')) {
      return isArabic
          ? 'هذا السجل موجود بالفعل في النظام.'
          : 'This record already exists.';
    } else if (code == '23503' || combined.contains('foreign key')) {
      return isArabic
          ? 'عملية غير صالحة: مرجع البيانات غير موجود.'
          : 'Invalid operation: referenced data does not exist.';
    } else if (code == 'PGRST301' || combined.contains('jwt expired') || combined.contains('unauthorized')) {
      return isArabic
          ? 'انتهت فترة الجلسة. يرجى تسجيل الدخول مجدداً.'
          : 'Session expired. Please log in again.';
    } else if (code == 'PGRST116' || combined.contains('json object requested, multiple')) {
      return isArabic
          ? 'حدث خطأ في استرجاع البيانات.'
          : 'An error occurred while retrieving data.';
    }

    // ── Network / connectivity errors ──
    if (combined.contains('network') ||
        combined.contains('socketexception') ||
        combined.contains('connection refused') ||
        combined.contains('timeout') ||
        combined.contains('handshake')) {
      return isArabic
          ? 'تعذر الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت.'
          : 'Network connection error. Please check your internet connection.';
    }

    // ── HTTP status codes ──
    if (details.contains('400') || details.contains('bad request')) {
      return isArabic
          ? 'طلب غير صالح. يرجى التحقق من البيانات المدخلة.'
          : 'Invalid request. Please check your input data.';
    } else if (details.contains('403') || details.contains('forbidden')) {
      return isArabic
          ? 'ليس لديك صلاحية لتنفيذ هذه العملية.'
          : 'You do not have permission to perform this action.';
    } else if (details.contains('500') || combined.contains('internal server error')) {
      return isArabic
          ? 'خطأ في الخادم. يرجى المحاولة لاحقاً.'
          : 'Server error. Please try again later.';
    }

    // ── Suppress raw technical / SQL / Postgrest internal exceptions ──
    if (combined.contains('postgrestexception') ||
        combined.contains('sqlstate') ||
        combined.contains('syntax error') ||
        combined.contains('violates') ||
        combined.contains('p000')) {
      return isArabic
          ? 'حدث خطأ في النظام أثناء معالجة العملية. يرجى المحاولة لاحقاً.'
          : 'A system error occurred. Please try again later.';
    }

    // Preserve explicitly user-facing strings while rejecting technical payloads.
    if (error is String) {
      final candidate = error.trim();
      final isTechnical = candidate.isEmpty ||
          candidate.startsWith('Exception:') ||
          candidate.contains('PostgrestException') ||
          candidate.contains('SocketException') ||
          candidate.contains('StackTrace') ||
          candidate.contains('SQLSTATE') ||
          candidate.contains(' at ') ||
          candidate.length > 180;
      if (!isTechnical) return candidate;
    }

    // Unknown technical messages must never be exposed to users.
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
