import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../data/models.dart';
import 'payment_checkout_service.dart';

/// Coordinates asynchronous polling, timers, subscriptions, and safe lock release
/// for the payment checkout screen.
class PaymentCheckoutCoordinator {
  SupabaseBookingRepository? _bookingRepo;
  Timer? _countdownTimer;
  Timer? _webhookTimeoutTimer;
  Timer? _fallbackPollingTimer;
  StreamSubscription? _bookingSubscription;

  PaymentCheckoutCoordinator({SupabaseBookingRepository? bookingRepo})
      : _bookingRepo = bookingRepo;

  @visibleForTesting
  SupabaseBookingRepository get bookingRepo => _bookingRepo ??= SupabaseBookingRepository();

  /// Starts a 1-second interval countdown timer.
  void startCountdownTimer({
    required int initialSeconds,
    required void Function(int remaining) onTick,
    required Future<void> Function() onExpired,
  }) {
    _countdownTimer?.cancel();
    int remaining = initialSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (remaining > 0) {
        remaining--;
        onTick(remaining);
      } else {
        timer.cancel();
        await onExpired();
      }
    });
  }

  /// Cancels the countdown timer.
  void cancelCountdownTimer() {
    _countdownTimer?.cancel();
  }

  /// Listens to real-time status changes for [bookingId].
  void listenToBookingStatus({
    required String bookingId,
    required void Function(Map<String, dynamic> data) onStatusUpdated,
    void Function(Object error)? onError,
  }) {
    if (bookingId.startsWith('mock_')) return;
    _bookingSubscription?.cancel();
    _bookingSubscription = bookingRepo.streamBookingStatus(bookingId).listen((data) {
      if (data.isNotEmpty) {
        onStatusUpdated(data.first);
      }
    }, onError: onError);
  }

  /// Starts periodic polling fallback if webhook is delayed.
  void startFallbackPolling({
    required String bookingId,
    required Future<Booking?> Function(String) fetchBooking,
    required void Function(Booking booking) onConfirmed,
  }) {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final booking = await fetchBooking(bookingId);
        if (booking != null && (booking.status == BookingStatus.confirmed || booking.isPaid)) {
          timer.cancel();
          _webhookTimeoutTimer?.cancel();
          _fallbackPollingTimer?.cancel();
          onConfirmed(booking);
        }
      } catch (e) {
        debugPrint('Fallback polling notice: $e');
      }
    });
  }

  /// Starts a timeout timer for awaiting webhook confirmation.
  void startWebhookTimeout({
    Duration timeout = const Duration(seconds: 300),
    required VoidCallback onTimeout,
  }) {
    _webhookTimeoutTimer?.cancel();
    _webhookTimeoutTimer = Timer(timeout, onTimeout);
  }

  /// Cancels active webhook timeout timer.
  void cancelWebhookTimeout() {
    _webhookTimeoutTimer?.cancel();
  }

  /// Safely releases the booking lock in database when user cancels or leaves.
  Future<void> releaseBookingSafely({
    required bool isTournamentPayment,
    required Booking? booking,
  }) async {
    cancelAllTimers();
    if (!isTournamentPayment && booking != null && !booking.id.startsWith('mock_')) {
      try {
        await bookingRepo.releaseBookingLock(booking.id);
      } catch (e) {
        debugPrint('Error releasing booking lock: $e');
      }
    }
  }

  /// Cleans up stale pending bookings for the user.
  Future<void> cleanupStaleBookings({
    required bool isTournamentPayment,
    required String userId,
    required String stadiumId,
  }) async {
    if (isTournamentPayment) return;
    await bookingRepo.cleanupStalePendingBookings(
      userId: userId,
      stadiumId: stadiumId,
    );
  }

  /// Simulates test payment webhook in development/staging.
  Future<void> simulateTestPaymentWebhook(String bookingId) async {
    await bookingRepo.simulateTestPaymentWebhook(bookingId);
  }

  /// Resolves the initial booking state (returns existing or creates a pending booking).
  Future<Booking?> resolveInitialBooking({
    required bool isTournamentPayment,
    required Booking? existingBooking,
    required String? existingBookingId,
    required String? userId,
    required BookingDraft bookingDraft,
    required Future<Booking?> Function(String id) fetchBookingById,
    required Future<Booking?> Function(BookingDraft draft, String userId) createBooking,
  }) async {
    if (isTournamentPayment) return null;
    if (existingBooking != null) return existingBooking;
    if (existingBookingId != null) {
      return await fetchBookingById(existingBookingId);
    }
    if (userId != null) {
      await cleanupStaleBookings(
        isTournamentPayment: isTournamentPayment,
        userId: userId,
        stadiumId: bookingDraft.stadiumId,
      );
      final draft = PaymentCheckoutService.preparePendingDraft(bookingDraft);
      return await createBooking(draft, userId);
    }
    return null;
  }

  /// Cancels all active timers and stream subscriptions.
  void cancelAllTimers() {
    _countdownTimer?.cancel();
    _webhookTimeoutTimer?.cancel();
    _fallbackPollingTimer?.cancel();
    _bookingSubscription?.cancel();
    _bookingSubscription = null;
  }

  /// Disposes coordinator resources.
  void dispose() {
    cancelAllTimers();
  }
}
