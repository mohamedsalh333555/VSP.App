import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/booking/booking_list_modifier.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('BookingListModifier Tests', () {
    final now = DateTime(2026, 9, 9, 20, 0);

    Booking makeBooking(String id, {bool isPaid = false}) {
      return Booking(
        id: id,
        stadiumId: 'std_1',
        stadiumName: 'Pitch 1',
        stadiumImageUrl: '',
        createdByUserId: 'user_1',
        playerPhone: '01000000000',
        ownerId: 'owner_1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        totalPrice: 400.0,
        status: BookingStatus.confirmed,
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        paymentMethod: 'cash',
        isPaid: isPaid,
        createdAt: now,
      );
    }

    test('insertBooking inserts at top of list', () {
      final list = [makeBooking('b1')];
      BookingListModifier.insertBooking(list, makeBooking('b2'));

      expect(list.length, 2);
      expect(list.first.id, 'b2');
    });

    test('removeBooking removes matching item', () {
      final list = [makeBooking('b1'), makeBooking('b2'), makeBooking('b3')];
      BookingListModifier.removeBooking(list, 'b2');

      expect(list.map((b) => b.id).toList(), ['b1', 'b3']);
    });

    test('updatePaymentStatus updates isPaid on matching booking', () {
      final list = [makeBooking('b1', isPaid: false), makeBooking('b2', isPaid: false)];
      BookingListModifier.updatePaymentStatus(list, 'b1', true);

      expect(list.first.isPaid, isTrue);
      expect(list.last.isPaid, isFalse);
    });

    test('formatCreationError strips exception prefixes', () {
      expect(
        BookingListModifier.formatCreationError('Exception: Failed to create booking: Slot occupied'),
        'Slot occupied',
      );
      expect(
        BookingListModifier.formatCreationError('Network timeout'),
        'Network timeout',
      );
    });

    test('applyDraftUpdates applies partial changes correctly', () {
      final draft = BookingDraft(
        stadiumId: 'std_1',
        stadiumName: 'Pitch 1',
        stadiumImageUrl: '',
        ownerId: 'owner_1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.openJoin,
        isPrivate: false,
        rentBall: false,
        totalPrice: 400.0,
      );

      final updated = BookingListModifier.applyDraftUpdates(
        draft,
        paymentMethod: 'wallet',
        totalPrice: 450.0,
        rentBall: true,
      );

      expect(updated.paymentMethod, 'wallet');
      expect(updated.totalPrice, 450.0);
      expect(updated.rentBall, isTrue);
      expect(updated.stadiumId, 'std_1');
    });
  });
}
