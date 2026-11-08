import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('BookingMapper Tests', () {
    final sampleMap = {
      'id': 'booking_999',
      'stadium_id': 'stadium_abc',
      'stadium_name': 'Green Arena',
      'owner_id': 'owner_xyz',
      'start_time': '2026-09-15T18:00:00.000Z',
      'end_time': '2026-09-15T19:00:00.000Z',
      'booking_type': 'challenge',
      'status': 'confirmed',
      'total_price': 300.0,
      'is_paid': true,
      'payment_method': 'cash',
      'created_by_user_id': 'user_111',
      'rent_ball': true,
      'is_private': false,
    };

    test('BookingMapper.fromFirestore correctly parses raw map', () {
      final booking = BookingMapper.fromFirestore(sampleMap, 'booking_999');

      expect(booking.id, 'booking_999');
      expect(booking.stadiumId, 'stadium_abc');
      expect(booking.stadiumName, 'Green Arena');
      expect(booking.bookingType, BookingType.challenge);
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.totalPrice, 300.0);
      expect(booking.isPaid, isTrue);
      expect(booking.rentBall, isTrue);
    });

    test('unknown server booking type is rejected rather than downgraded', () {
      final corrupted = {...sampleMap, 'booking_type': 'new_challenge_format'};
      expect(
        () => BookingMapper.fromFirestore(corrupted, 'booking_999'),
        throwsFormatException,
      );
    });

    test('unknown booking status is rejected rather than becoming pending', () {
      final corrupted = {...sampleMap, 'status': 'paid_under_review'};
      expect(
        () => BookingMapper.fromFirestore(corrupted, 'booking_999'),
        throwsFormatException,
      );
    });

    test('legacy upcoming status maps to canonical confirmed', () {
      final legacy = {...sampleMap, 'status': 'upcoming'};
      expect(
        BookingMapper.fromFirestore(legacy, 'booking_999').status,
        BookingStatus.confirmed,
      );
    });

    test('malformed booking time interval is rejected', () {
      final invalid = {
        ...sampleMap,
        'end_time': sampleMap['start_time'],
      };
      expect(
        () => BookingMapper.fromFirestore(invalid, 'booking_999'),
        throwsFormatException,
      );
    });

    test('legacy enum-qualified booking type is restored', () {
      final legacy = {...sampleMap, 'booking_type': 'BookingType.open_join'};
      final booking = BookingMapper.fromFirestore(legacy, 'booking_999');
      expect(booking.bookingType, BookingType.openJoin);
    });

    test('Booking.fromFirestore and booking.toFirestore round-trip preserves core fields', () {
      final booking = Booking.fromFirestore(sampleMap, 'booking_999');
      final outputMap = booking.toFirestore();

      expect(outputMap['stadium_id'], 'stadium_abc');
      expect(outputMap['total_price'], 300.0);
      expect(outputMap['status'], 'confirmed');
      expect(outputMap['booking_type'], 'challenge');
      expect(outputMap['is_paid'], isTrue);
    });
  });
}
