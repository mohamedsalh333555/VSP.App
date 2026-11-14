import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../services/logger_service.dart';
import '../services/notification_handler.dart';
import 'booking/booking_cancellation_coordinator.dart';
import 'booking/cash_collection_validation.dart';
import 'booking/booking_creation_coordinator.dart';
import 'booking/booking_query_coordinator.dart';
import 'booking/booking_reconciliation_service.dart';
import 'booking/booking_schedule_coordinator.dart';
import 'notification_repository.dart';
import 'team_repository.dart';
import 'user_repository.dart';

/// Abstract BookingRepository interface
abstract class BookingRepository {
  Future<Booking> createBooking(BookingDraft draft, String userId);
  Stream<List<Booking>> getUserBookings(String userId);
  Future<List<Booking>> getUserBookingsDirectly(String userId);
  Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds});
  Future<Booking?> getBookingById(String bookingId);
  Future<Booking?> getBookingByIdStrict(String bookingId);
  Future<bool> updateBookingStatus(String bookingId, BookingStatus status);
  Future<bool> cancelBooking(String bookingId);
  Stream<List<Booking>> getUpcomingBookings(String userId);
  Stream<List<Booking>> getBookingHistory(String userId);
  Future<bool> submitMatchResult({
    required String bookingId,
    required String teamId,
    required MatchOutcome outcome,
    double? rating,
    String? review,
  });
  Future<bool> updatePaymentStatus(String bookingId, bool isPaid);
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date);
  Future<List<Booking>> fetchStadiumBookingsDirectly(String stadiumId, DateTime date);
  Future<void> autoReconcilePastBookings(String ownerId);
  Future<List<Booking>> getUnpaidBookingsForUser(String userId);
  Future<void> autoExpirePendingChallenges();
  Future<void> autoReconcileSingleEntryResults();
  Future<void> autoNudgePostMatchResults();

  Future<bool> updateManualBooking({
    required String bookingId,
    required String name,
    required String phone,
    required String notes,
    required bool isDepositPaid,
    required double depositPaid,
    required String paymentStatus,
  });

  Future<bool> requestReschedule({
    required String bookingId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  });

  Future<bool> respondToReschedule({
    required String bookingId,
    required bool accept,
  });

  Future<Map<String, dynamic>> requestEmergencyClosure({
    required String stadiumId,
    required String ownerId,
    required String reason,
    required int durationHours,
  });

  Future<void> cleanupStalePendingBookings({
    required String userId,
    required String stadiumId,
  });

  Stream<List<Map<String, dynamic>>> streamBookingStatus(String bookingId);
  Stream<List<Map<String, dynamic>>> streamBookingRaw(String bookingId);
  Future<void> simulateTestPaymentWebhook(String bookingId);
  Future<void> releaseBookingLock(String bookingId);
}

/// Supabase implementation of BookingRepository
class SupabaseBookingRepository implements BookingRepository {
  final SupabaseClient? _client;
  late final BookingCreationCoordinator _creationCoordinator;
  late final BookingCancellationCoordinator _cancellationCoordinator;
  late final BookingReconciliationService _reconciliationService;
  late final BookingScheduleCoordinator _scheduleCoordinator;
  late final BookingQueryCoordinator _queryCoordinator;

  SupabaseBookingRepository({
    SupabaseClient? client,
    NotificationRepository? notificationRepository,
    UserRepository? userRepository,
    TeamRepository? teamRepository,
    BookingCreationCoordinator? creationCoordinator,
    BookingCancellationCoordinator? cancellationCoordinator,
    BookingReconciliationService? reconciliationService,
    BookingScheduleCoordinator? scheduleCoordinator,
    BookingQueryCoordinator? queryCoordinator,
  }) : _client = client {
    _creationCoordinator = creationCoordinator ??
        BookingCreationCoordinator(
          client: _client,
          notificationRepository: notificationRepository,
          userRepository: userRepository,
          teamRepository: teamRepository,
        );
    _cancellationCoordinator = cancellationCoordinator ??
        BookingCancellationCoordinator(client: _client);
    _reconciliationService = reconciliationService ??
        BookingReconciliationService(
          client: _client,
          notificationRepository: notificationRepository,
          userRepository: userRepository,
          teamRepository: teamRepository,
        );
    _scheduleCoordinator = scheduleCoordinator ??
        BookingScheduleCoordinator(client: _client);
    _queryCoordinator = queryCoordinator ??
        BookingQueryCoordinator(client: _client);
  }

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<Booking> createBooking(BookingDraft draft, String userId) {
    return _creationCoordinator.createBooking(
      draft: draft,
      userId: userId,
      getBookingById: getBookingById,
    );
  }

  @override
  Stream<List<Booking>> getUserBookings(String userId) =>
      _queryCoordinator.getUserBookings(userId);

  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) =>
      _queryCoordinator.getUserBookingsDirectly(userId);

  /// Strict sync fetch: propagates transport/query failures instead of returning
  /// an empty list that could be mistaken for an authoritative no-bookings state.
  Future<List<Booking>> getUserBookingsDirectlyStrict(String userId) =>
      _queryCoordinator.getUserBookingsDirectlyStrict(userId);

  Future<List<Booking>> fetchOwnerBookingsDirectly(String ownerId, {List<String>? stadiumIds}) =>
      _queryCoordinator.fetchOwnerBookingsDirectly(ownerId, stadiumIds: stadiumIds);

  Future<List<Booking>> fetchOwnerBookingsDirectlyStrict(String ownerId, {List<String>? stadiumIds}) =>
      _queryCoordinator.fetchOwnerBookingsDirectlyStrict(ownerId, stadiumIds: stadiumIds);

  @override
  Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds}) =>
      _queryCoordinator.getOwnerBookings(ownerId, stadiumIds: stadiumIds);

  @override
  Future<Booking?> getBookingById(String bookingId) =>
      _queryCoordinator.getBookingById(bookingId);

  @override
  Future<Booking?> getBookingByIdStrict(String bookingId) =>
      _queryCoordinator.getBookingByIdStrict(bookingId);

  @override
  Future<bool> updateBookingStatus(String bookingId, BookingStatus status) async {
    try {
      await _supabase
          .from('bookings')
          .update({
            'status': status.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', bookingId);
      return true;
    } catch (_) {
      debugPrint('Booking status update failed (details redacted)');
      return false;
    }
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    final booking = await getBookingById(bookingId);
    return _cancellationCoordinator.cancelBooking(booking: booking, bookingId: bookingId);
  }

  @override
  Stream<List<Booking>> getUpcomingBookings(String userId) =>
      _queryCoordinator.getUpcomingBookings(userId);

  @override
  Stream<List<Booking>> getBookingHistory(String userId) =>
      _queryCoordinator.getBookingHistory(userId);

  @override
  Future<bool> submitMatchResult({
    required String bookingId,
    required String teamId,
    required MatchOutcome outcome,
    double? rating,
    String? review,
  }) async {
    final booking = await getBookingById(bookingId);
    if (booking == null) return false;
    return _reconciliationService.submitMatchResult(
      booking: booking,
      teamId: teamId,
      outcome: outcome,
      rating: rating,
      review: review,
    );
  }

  @override
  Future<List<Booking>> fetchStadiumBookingsDirectly(String stadiumId, DateTime date) =>
      _queryCoordinator.fetchStadiumBookingsDirectly(stadiumId, date);

  @override
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) =>
      _queryCoordinator.getBookingsForStadium(stadiumId, date);

  @override
  Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
    // There is no authorized reversal RPC in this flow. Never claim a
    // transition to unpaid succeeded when nothing was written to the server.
    if (!isPaid) return false;

    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) return false;

      // Idempotent confirmation must not collect twice or send duplicate
      // receipts. Inconsistent paid flags require authoritative repair.
      if (booking.isPaid) {
        // A settled authoritative read is idempotent. A contradictory paid
        // flag/status must fail closed rather than create a second settlement.
        return booking.paymentStatus == 'paid' ||
            booking.paymentStatus == 'fully_paid';
      }
      if (booking.paymentStatus == 'paid' ||
          booking.paymentStatus == 'fully_paid') {
        return false;
      }

      // A digital deposit is not cash. Collect only the remaining verified
      // portion, never the full total again after a complete deposit.
      final cashDue = CashCollectionValidation.calculateDue(
        totalPrice: booking.totalPrice,
        depositPaid: booking.depositPaid,
        paymentMethod: booking.paymentMethod,
        paymentStatus: booking.paymentStatus,
        isPaid: booking.isPaid,
      );
      if (cashDue == null) return false;
      // A zero balance is sent to the RPC only to reconcile a complete
      // existing deposit; its idempotent response must never send a receipt.

      final rpcRes = await _supabase.rpc('confirm_cash_booking_atomic', params: {
        'p_booking_id': bookingId,
        'p_owner_id': booking.ownerId,
        'p_total_price': booking.totalPrice,
        'p_collected_amount': cashDue,
      });

      // Only an explicit server-confirmed success may update payment UI.
      if (rpcRes is! Map || rpcRes['success'] != true) {
        VSPLogger.w('Cash collection was not confirmed (details redacted)');
        return false;
      }
      if (rpcRes['already_confirmed'] == true) {
        return true; // Retry/replay: never dispatch another receipt.
      }

      final playerUserId = booking.userId;
      if (playerUserId.isNotEmpty && playerUserId != booking.ownerId) {
        try {
          await NotificationHandler.notifyPaymentReceived(
            recipientId: playerUserId,
            userName: booking.stadiumName,
            amount: cashDue,
            bookingId: bookingId,
          );
        } catch (_) {
          // Collection has succeeded; notification failure cannot undo it.
          VSPLogger.w('Player payment receipt notification failed (details redacted)');
        }
      }
      return true;
    } catch (_) {
      debugPrint('Cash payment confirmation failed (details redacted)');
      return false;
    }
  }

  @override
  Future<void> autoReconcilePastBookings(String ownerId) =>
      _reconciliationService.autoReconcilePastBookings();

  @override
  Future<List<Booking>> getUnpaidBookingsForUser(String userId) =>
      _queryCoordinator.getUnpaidBookingsForUser(userId);

  @override
  Future<void> autoExpirePendingChallenges() =>
      _reconciliationService.autoExpirePendingChallenges();

  @override
  Future<void> autoReconcileSingleEntryResults() =>
      _reconciliationService.autoReconcileSingleEntryResults();

  @override
  Future<void> autoNudgePostMatchResults() =>
      _reconciliationService.autoNudgePostMatchResults();

  @override
  Future<bool> updateManualBooking({
    required String bookingId,
    required String name,
    required String phone,
    required String notes,
    required bool isDepositPaid,
    required double depositPaid,
    required String paymentStatus,
  }) async {
    final booking = await getBookingById(bookingId);
    return _scheduleCoordinator.updateManualBooking(
      booking: booking,
      bookingId: bookingId,
      name: name,
      phone: phone,
      notes: notes,
      isDepositPaid: isDepositPaid,
      depositPaid: depositPaid,
      paymentStatus: paymentStatus,
    );
  }

  @override
  Future<bool> requestReschedule({
    required String bookingId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) =>
      _scheduleCoordinator.requestReschedule(
        bookingId: bookingId,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
      );

  @override
  Future<bool> respondToReschedule({
    required String bookingId,
    required bool accept,
  }) async {
    final booking = await getBookingById(bookingId);
    return _scheduleCoordinator.respondToReschedule(
      booking: booking,
      bookingId: bookingId,
      accept: accept,
    );
  }

  @override
  Future<Map<String, dynamic>> requestEmergencyClosure({
    required String stadiumId,
    required String ownerId,
    required String reason,
    required int durationHours,
  }) =>
      _scheduleCoordinator.requestEmergencyClosure(
        stadiumId: stadiumId,
        ownerId: ownerId,
        reason: reason,
        durationHours: durationHours,
      );

  @override
  Future<void> cleanupStalePendingBookings({
    required String userId,
    required String stadiumId,
  }) =>
      _scheduleCoordinator.cleanupStalePendingBookings(
        userId: userId,
        stadiumId: stadiumId,
      );

  @override
  Stream<List<Map<String, dynamic>>> streamBookingStatus(String bookingId) =>
      _queryCoordinator.streamBookingStatus(bookingId);

  @override
  Stream<List<Map<String, dynamic>>> streamBookingRaw(String bookingId) =>
      _queryCoordinator.streamBookingRaw(bookingId);

  @override
  Future<void> simulateTestPaymentWebhook(String bookingId) =>
      _scheduleCoordinator.simulateTestPaymentWebhook(bookingId);

  @override
  Future<void> releaseBookingLock(String bookingId) =>
      _scheduleCoordinator.releaseBookingLock(bookingId);
}