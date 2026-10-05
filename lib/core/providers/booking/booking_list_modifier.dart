import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_error_handler.dart';
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
  /// Delegated to unified AppErrorHandler SSOT (H-05).
  static String formatCreationError(dynamic error) {
    if (error == null) return 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.';
    if (error is PostgrestException) {
      return AppErrorHandler.formatError(error, isArabic: true);
    }
    final str = error.toString().trim();
    final upper = str.toUpperCase();
    if (upper.contains('STADIUM_LIMIT_EXCEEDED') ||
        upper.contains('SLOT_LOCKED_OR_TAKEN') ||
        upper.contains('CANNOT_CONFIRM_CANCELLED_BOOKING') ||
        upper.contains('ACTIVE_BOOKINGS_EXIST') ||
        upper.contains('DISPUTE_WINDOW_EXPIRED') ||
        upper.contains('NOT_AT_STADIUM') ||
        str.contains('PostgrestException') ||
        str.contains('code:')) {
      return AppErrorHandler.formatError(error, isArabic: true);
    }
    if (str.startsWith('Exception: Failed to create booking: ')) {
      return str.replaceFirst('Exception: Failed to create booking: ', '').trim();
    }
    if (str.startsWith('Exception: ')) {
      return str.replaceFirst('Exception: ', '').trim();
    }
    return str;
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
    String? challengeCode,
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
      challengeCode: challengeCode,
    );
  }
}
