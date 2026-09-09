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
  static void updatePaymentStatus(List<Booking> list, String bookingId, bool isPaid) {
    final index = list.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      list[index] = list[index].copyWith(isPaid: isPaid);
    }
  }

  /// Cleans and formats database/network exception message for user presentation.
  static String formatCreationError(dynamic error) {
    return error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('Failed to create booking: ', '');
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
