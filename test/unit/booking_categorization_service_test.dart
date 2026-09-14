import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/booking/booking_categorization_service.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('BookingCategorizationService Unit Tests', () {
    final now = DateTime(2026, 9, 10, 18, 0);

    final futureBooking = Booking(
      id: 'b_future',
      stadiumId: 'std_1',
      stadiumName: 'Cairo Stadium',
      stadiumImageUrl: '',
      ownerId: 'own_1',
      startTime: now.add(const Duration(hours: 2)),
      endTime: now.add(const Duration(hours: 3)),
      bookingType: BookingType.personal,
      playerTeamName: 'Stars',
      playerPhone: '01012345678',
      totalPrice: 300.0,
      currentPlayers: 10,
      status: BookingStatus.confirmed,
      paymentStatus: 'paid',
      paymentMethod: 'cash',
      isPaid: true,
      isPrivate: true,
      rentBall: false,
      createdByUserId: 'user_1',
      createdAt: now.subtract(const Duration(minutes: 30)),
    );

    final pastBooking = Booking(
      id: 'b_past',
      stadiumId: 'std_1',
      stadiumName: 'Cairo Stadium',
      stadiumImageUrl: '',
      ownerId: 'own_1',
      startTime: now.subtract(const Duration(hours: 3)),
      endTime: now.subtract(const Duration(hours: 2)),
      bookingType: BookingType.personal,
      playerTeamName: 'Stars',
      playerPhone: '01012345678',
      totalPrice: 300.0,
      currentPlayers: 10,
      status: BookingStatus.completed,
      paymentStatus: 'paid',
      paymentMethod: 'cash',
      isPaid: true,
      isPrivate: true,
      rentBall: false,
      createdByUserId: 'user_1',
      createdAt: now.subtract(const Duration(days: 1)),
    );

    final pendingRecentBooking = Booking(
      id: 'b_pending',
      stadiumId: 'std_2',
      stadiumName: 'Giza Arena',
      stadiumImageUrl: '',
      ownerId: 'own_1',
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 2)),
      bookingType: BookingType.personal,
      playerTeamName: 'Stars',
      playerPhone: '01012345678',
      totalPrice: 300.0,
      currentPlayers: 10,
      status: BookingStatus.pending,
      paymentStatus: 'pending',
      paymentMethod: 'paymob',
      isPaid: false,
      isPrivate: true,
      rentBall: false,
      createdByUserId: 'user_1',
      createdAt: now.subtract(const Duration(minutes: 5)),
    );

    test('categorizeUserBookings accurately separates upcoming, pending, and history', () {
      final categorized = BookingCategorizationService.categorizeUserBookings(
        bookings: [futureBooking, pastBooking, pendingRecentBooking],
        now: now,
      );

      expect(categorized.upcoming.length, 1);
      expect(categorized.upcoming.first.id, 'b_future');
      expect(categorized.pending.length, 1);
      expect(categorized.pending.first.id, 'b_pending');
      expect(categorized.history.length, 1);
      expect(categorized.history.first.id, 'b_past');
    });

    test('categorizeOwnerBookings accurately separates confirmed future vs completed/cancelled', () {
      final categorized = BookingCategorizationService.categorizeOwnerBookings(
        bookings: [futureBooking, pastBooking, pendingRecentBooking],
        now: now,
      );

      expect(categorized.upcoming.length, 1);
      expect(categorized.upcoming.first.id, 'b_future');
      expect(categorized.history.length, 1);
      expect(categorized.history.first.id, 'b_past');
    });

    test('mergeLocalManualBookings preserves local active manual bookings not in incoming stream', () {
      final manualLocal = Booking(
        id: 'b_manual_1',
        stadiumId: 'std_3',
        stadiumName: 'Manual Stadium',
        stadiumImageUrl: '',
        ownerId: 'own_1',
        startTime: now.add(const Duration(hours: 4)),
        endTime: now.add(const Duration(hours: 5)),
        bookingType: BookingType.personal,
        playerTeamName: 'Walk-in',
        playerPhone: '01000000000',
        totalPrice: 200.0,
        currentPlayers: 10,
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        paymentMethod: 'cash',
        paymentTransactionId: 'MANUAL_12345',
        isPaid: true,
        isPrivate: true,
        rentBall: false,
        createdByUserId: 'own_1',
        createdAt: now,
      );

      final merged = BookingCategorizationService.mergeLocalManualBookings(
        incomingBookings: [futureBooking],
        currentBookings: [manualLocal],
        cancellingIds: {},
      );

      expect(merged.length, 2);
      expect(merged.any((b) => b.id == 'b_manual_1'), isTrue);
    });

    test('formatPublicMatchError handles recognized and unknown errors cleanly', () {
      expect(BookingCategorizationService.formatPublicMatchError('time_conflict detected'), 'time_conflict');
      expect(BookingCategorizationService.formatPublicMatchError('Error: match_is_full'), 'match_is_full');
      expect(BookingCategorizationService.formatPublicMatchError('already_joined error'), 'already_joined');
      expect(BookingCategorizationService.formatPublicMatchError('Exception: Network timeout'), 'Network timeout');
    });
  });
}
