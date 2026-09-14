import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';

/// Pure domain helper for modifying booking lists and drafts in BookingProvider.
class BookingListModifier {
  const BookingListModifier._();

  /// Inserts a newly created booking at the top of [list].
  static void insertBooking(List<Booking> list, Booking booking) {
    list.insert(0, booking);
  }

  /// Removes booking with [bookingId] from [list].
  static void removeBooking(List<Booking> list, String bookingId) {
    list.removeWhere((b) => b.id == bookingId);
  }

  /// Updates the payment status of booking with [bookingId] in [list].
  static void updatePaymentStatus(
    List<Booking> list,
    String bookingId,
    bool isPaid,
  ) {
    final index = list.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      list[index] = list[index].copyWith(
        isPaid: isPaid,
        paymentStatus: isPaid ? 'paid' : list[index].paymentStatus,
        depositPaid: isPaid ? list[index].totalPrice : list[index].depositPaid,
      );
    }
  }

  /// Cleans and formats database/network exception message for user presentation.
  static String formatCreationError(dynamic error) {
    if (error == null) return 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.';

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

    final combined = '$code $message $details';

    // 1. Check machine-readable tokens and business codes first
    if (combined.contains('SLOT_LOCKED_OR_TAKEN') ||
        combined.contains('slot already booked') ||
        combined.contains('هذا الوقت محجوز بالفعل')) {
      return 'الوقت المحدد محجوز بالفعل، يرجى اختيار موعد آخر';
    }
    if (combined.contains('STADIUM_LIMIT_EXCEEDED') ||
        combined.contains('الحد الأقصى للملاعب') ||
        combined.contains('stadium limit exceeded')) {
      return 'تم تجاوز الحد الأقصى للملاعب المسموح بها في باقتك';
    }
    if (combined.contains('CANNOT_CONFIRM_CANCELLED_BOOKING') ||
        combined.contains('حجز ملغي')) {
      return 'لا يمكن تحصيل حجز ملغي';
    }
    if (combined.contains('no_show') || combined.contains('تكرار عدم الحضور')) {
      return 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.';
    }
    if (combined.contains('حجز نقدي نشط')) {
      return 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.';
    }
    if (combined.contains('active_bookings_exist')) {
      return 'لا يمكن حذف الملعب لوجود مباريات وحجوزات نشطة جارية أو قادمة.';
    }
    if (combined.contains('انتهت صلاحية باقة الاشتراك')) {
      return 'انتهت صلاحية باقة الاشتراك الخاصة بك. يرجى تجديد الاشتراك لإضافة أو تفعيل الملاعب.';
    }

    // 2. Suppress raw technical / SQL / Postgrest internal exceptions from reaching users
    final lower = combined.toLowerCase();
    if (lower.contains('postgrestexception') ||
        lower.contains('sqlstate') ||
        lower.contains('syntax error') ||
        lower.contains('violates') ||
        lower.contains('p000') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('internal server error')) {
      return 'حدث خطأ في النظام أثناء معالجة الحجز. يرجى المحاولة لاحقاً.';
    }

    final cleaned = message
        .replaceAll(RegExp(r'PostgrestException\(message:\s*'), '')
        .replaceAll(RegExp(r',\s*code:\s*.*\)$'), '')
        .replaceAll('Exception: ', '')
        .replaceAll('Failed to create booking: ', '')
        .trim();

    return cleaned.isNotEmpty
        ? cleaned
        : 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.';
  }

  /// Applies partial updates to [draft] immutably.
  static BookingDraft applyDraftUpdates(
    BookingDraft draft, {
    String? paymentMethod,
    String? paymentTransactionId,
    bool? isPrivate,
    bool? rentBall,
    double? totalPrice,
    DateTime? startTime,
    DateTime? endTime,
    BookingType? bookingType,
    String? opponentTeamId,
    String? opponentTeamName,
    String? playerTeamId,
    String? playerTeamName,
    int? currentPlayers,
    int? maxPlayers,
  }) {
    return draft.copyWith(
      paymentMethod: paymentMethod,
      paymentTransactionId: paymentTransactionId,
      isPrivate: isPrivate,
      rentBall: rentBall,
      totalPrice: totalPrice,
      startTime: startTime,
      endTime: endTime,
      bookingType: bookingType,
      opponentTeamId: opponentTeamId,
      opponentTeamName: opponentTeamName,
      playerTeamId: playerTeamId,
      playerTeamName: playerTeamName,
      currentPlayers: currentPlayers,
      totalFieldCapacity: maxPlayers,
    );
  }
}
