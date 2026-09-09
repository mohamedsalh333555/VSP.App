import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/booking_models.dart';
import '../booking_repository.dart';

/// Mock implementation of [BookingRepository] for testing and demo environments.
class MockBookingRepository implements BookingRepository {
  final List<Booking> _bookings = [];
  final _controller = StreamController<List<Booking>>.broadcast();

  @override
  Future<bool> requestReschedule({
    required String bookingId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async => true;

  @override
  Future<bool> respondToReschedule({
    required String bookingId,
    required bool accept,
  }) async => true;

  @override
  Future<Map<String, dynamic>> requestEmergencyClosure({
    required String stadiumId,
    required String ownerId,
    required String reason,
    required int durationHours,
  }) async => {'success': true};

  void _update() {
    _controller.add(List.from(_bookings));
  }

  @override
  Future<Booking> createBooking(BookingDraft draft, String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    const status = BookingStatus.confirmed;

    final booking = Booking.fromDraft(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      draft: draft,
      userId: userId,
      status: status,
    );

    _bookings.add(booking);
    _update();
    debugPrint('Mock Booking created: ${booking.id}');
    return booking;
  }

  @override
  Stream<List<Booking>> getUserBookings(String userId) async* {
    yield _bookings.where((b) => b.createdByUserId == userId).toList();
    yield* _controller.stream.map(
      (bookings) => bookings.where((b) => b.createdByUserId == userId).toList(),
    );
  }

  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) async {
    return _bookings.where((b) => b.createdByUserId == userId || b.userId == userId).toList();
  }

  @override
  Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds}) async* {
    yield _bookings.where((b) => b.ownerId == ownerId).toList();
    yield* _controller.stream.map(
      (bookings) => bookings.where((b) => b.ownerId == ownerId).toList(),
    );
  }

  @override
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      return _bookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> updateBookingStatus(String bookingId, BookingStatus status) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(status: status);
      _update();
    }
    return true;
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    return updateBookingStatus(bookingId, BookingStatus.cancelled);
  }

  @override
  Stream<List<Booking>> getUpcomingBookings(String userId) {
    final now = DateTime.now();
    return getUserBookings(userId).map(
      (bookings) => bookings
          .where((b) => b.status == BookingStatus.confirmed && b.startTime.isAfter(now))
          .toList(),
    );
  }

  @override
  Stream<List<Booking>> getBookingHistory(String userId) {
    return getUserBookings(userId).map(
      (bookings) => bookings
          .where((b) => b.status == BookingStatus.completed || b.isCompleted)
          .toList(),
    );
  }

  @override
  Future<bool> submitMatchResult({
    required String bookingId,
    required String teamId,
    required MatchOutcome outcome,
    double? rating,
    String? review,
  }) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) return false;

    final booking = _bookings[index];

    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      _bookings[index] = booking.copyWith(
        pendingOutcome: outcome,
        resultSubmittedByTeamId: teamId,
        matchResultStatus: MatchResultStatus.waitingOpponent,
      );
      _update();
      return true;
    } else if (booking.matchResultStatus == MatchResultStatus.waitingOpponent &&
        booking.resultSubmittedByTeamId != teamId) {
      if (booking.pendingOutcome == outcome) {
        _bookings[index] = booking.copyWith(
          finalOutcome: outcome,
          matchResultStatus: MatchResultStatus.confirmed,
          status: BookingStatus.completed,
          pendingOutcome: null,
          resultSubmittedByTeamId: null,
        );
        _update();
        return true;
      } else {
        _bookings[index] = booking.copyWith(
          matchResultStatus: MatchResultStatus.disputed,
        );
        _update();
        return false;
      }
    }
    return false;
  }

  @override
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Stream.value(_bookings
        .where((b) =>
            b.stadiumId == stadiumId &&
            b.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            b.startTime.isBefore(endOfDay) &&
            b.status != BookingStatus.cancelled)
        .toList());
  }

  @override
  Future<List<Booking>> fetchStadiumBookingsDirectly(String stadiumId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _bookings
        .where((b) =>
            b.stadiumId == stadiumId &&
            b.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            b.startTime.isBefore(endOfDay) &&
            b.status != BookingStatus.cancelled)
        .toList();
  }

  @override
  Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(isPaid: isPaid);
      _update();
    }
    return true;
  }

  @override
  Future<void> autoReconcilePastBookings(String ownerId) async {}

  @override
  Future<List<Booking>> getUnpaidBookingsForUser(String userId) async {
    return _bookings.where((b) => b.createdByUserId == userId && !b.isPaid).toList();
  }

  @override
  Future<void> autoExpirePendingChallenges() async {}

  @override
  Future<void> autoReconcileSingleEntryResults() async {}

  @override
  Future<void> autoNudgePostMatchResults() async {}

  @override
  Future<bool> updateManualBooking({
    required String bookingId,
    required String name,
    required String phone,
    required String notes,
    required bool isDepositPaid,
    required double depositPaid,
    required String paymentStatus,
  }) async => true;

  @override
  Future<void> cleanupStalePendingBookings({
    required String userId,
    required String stadiumId,
  }) async {}

  @override
  Stream<List<Map<String, dynamic>>> streamBookingStatus(String bookingId) {
    return Stream.value([]);
  }

  @override
  Stream<List<Map<String, dynamic>>> streamBookingRaw(String bookingId) {
    return Stream.value([]);
  }

  @override
  Future<void> simulateTestPaymentWebhook(String bookingId) async {}

  @override
  Future<void> releaseBookingLock(String bookingId) async {}

  /// Add mock bookings for testing
  void addMockBookings() {
    final now = DateTime.now();

    _bookings.add(Booking(
      id: 'mock_1',
      stadiumId: '1',
      stadiumName: 'Santiago Bernabéu',
      stadiumImageUrl: 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800',
      ownerId: 'owner_1',
      startTime: now.add(const Duration(days: 2, hours: 3)),
      endTime: now.add(const Duration(days: 2, hours: 5)),
      bookingType: BookingType.personal,
      isPrivate: false,
      rentBall: true,
      totalPrice: 140,
      paymentMethod: 'card',
      status: BookingStatus.confirmed,
      createdByUserId: 'demo_user',
      createdAt: now.subtract(const Duration(days: 1)),
    ));

    _bookings.add(Booking(
      id: 'mock_2',
      stadiumId: '2',
      stadiumName: 'Camp Nou',
      stadiumImageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
      ownerId: 'owner_2',
      startTime: now.subtract(const Duration(days: 5, hours: 3)),
      endTime: now.subtract(const Duration(days: 5, hours: 1)),
      bookingType: BookingType.team,
      playerTeamId: 'team_1',
      playerTeamName: 'Real Madrid CF',
      isPrivate: true,
      rentBall: false,
      totalPrice: 180,
      paymentMethod: 'wallet',
      status: BookingStatus.completed,
      createdByUserId: 'demo_user',
      createdAt: now.subtract(const Duration(days: 6)),
    ));
  }
}
