import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/booking_sheet/owner_booking_sheet_service.dart';

void main() {
  group('OwnerBookingSheetService State Flags & Slot Formatting', () {
    final now = DateTime(2026, 9, 9, 18, 0);

    test('resolveStateFlags correctly identifies new slot', () {
      final flags = OwnerBookingSheetService.resolveStateFlags(
        isEditProp: false,
        booking: null,
        now: now,
      );

      expect(flags.isNewSlot, isTrue);
      expect(flags.isEdit, isFalse);
      expect(flags.isPastCompleted, isFalse);
      expect(flags.isReadOnly, isFalse);
    });

    test('resolveStateFlags correctly identifies past completed booking', () {
      final pastBooking = Booking(
        id: 'b1',
        stadiumId: 's1',
        stadiumName: 'Pitch',
        ownerId: 'own1',
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.subtract(const Duration(hours: 2)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 150.0,
        paymentMethod: 'cash',
        status: BookingStatus.completed,
        createdByUserId: 'u1',
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final flags = OwnerBookingSheetService.resolveStateFlags(
        isEditProp: true,
        booking: pastBooking,
        now: now,
      );

      expect(flags.isEdit, isTrue);
      expect(flags.isPastCompleted, isTrue);
      expect(flags.isReadOnly, isTrue);
    });

    test('resolveStateFlags identifies ongoing active match', () {
      final activeBooking = Booking(
        id: 'b2',
        stadiumId: 's1',
        stadiumName: 'Pitch',
        ownerId: 'own1',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now.add(const Duration(minutes: 30)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 150.0,
        paymentMethod: 'cash',
        status: BookingStatus.confirmed,
        createdByUserId: 'u1',
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final flags = OwnerBookingSheetService.resolveStateFlags(
        isEditProp: true,
        booking: activeBooking,
        now: now,
      );

      expect(flags.isOngoingActiveMatch, isTrue);
      expect(flags.isPastCompleted, isFalse);
    });

    test('formatSlotTime formats time for new slot and existing booking', () {
      final baseDate = DateTime(2026, 9, 9);
      final newSlotTime = OwnerBookingSheetService.formatSlotTime(
        isEdit: false,
        booking: null,
        baseDate: baseDate,
        selectedDayIndex: 0,
        slot: {'hour': 18, 'minute': 0},
      );

      expect(newSlotTime, contains('06:00 PM'));

      final existingBooking = Booking(
        id: 'b3',
        stadiumId: 's1',
        stadiumName: 'Pitch',
        ownerId: 'own1',
        startTime: DateTime(2026, 9, 9, 20, 30),
        endTime: DateTime(2026, 9, 9, 21, 30),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 150.0,
        paymentMethod: 'cash',
        status: BookingStatus.confirmed,
        createdByUserId: 'u1',
        createdAt: baseDate,
      );

      final existingTime = OwnerBookingSheetService.formatSlotTime(
        isEdit: true,
        booking: existingBooking,
        baseDate: baseDate,
        selectedDayIndex: 0,
        slot: {},
      );

      expect(existingTime, contains('08:30 PM'));
    });
  });
}
