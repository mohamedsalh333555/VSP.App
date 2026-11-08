import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/booking_enums.dart';
import 'package:vsp_application/data/models/booking_draft.dart';

void main() {
  group('BookingDraft & BookingEnums', () {
    test('BookingType enum values contain expected items', () {
      expect(BookingType.values, contains(BookingType.personal));
      expect(BookingType.values, contains(BookingType.openJoin));
      expect(BookingType.values, contains(BookingType.challenge));
      expect(BookingType.values, contains(BookingType.team));
      expect(BookingType.values, contains(BookingType.matchup));
    });

    test('BookingStatus enum values contain expected items', () {
      expect(BookingStatus.values, contains(BookingStatus.pending));
      expect(BookingStatus.values, contains(BookingStatus.confirmed));
      expect(BookingStatus.values, contains(BookingStatus.upcoming));
      expect(BookingStatus.values, contains(BookingStatus.completed));
      expect(BookingStatus.values, contains(BookingStatus.cancelled));
    });

    test('BookingDraft toMap and fromMap serialization matches accurately', () {
      final now = DateTime(2026, 9, 9, 20, 0);
      final draft = BookingDraft(
        stadiumId: 'std-123',
        stadiumName: 'Al Ahly Arena',
        stadiumImageUrl: 'https://example.com/stadium.png',
        ownerId: 'owner-456',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.openJoin,
        isPrivate: false,
        rentBall: true,
        totalPrice: 200.0,
        currency: 'EGP',
        depositPaid: 50.0,
        isDepositPaid: true,
        isPaid: true,
        needsDeposit: true,
        currentPlayers: 4,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        playerPhone: '01000000000',
        paymentMethod: 'vodafone_cash',
      );

      final map = draft.toMap();
      expect(map['stadiumId'], equals('std-123'));
      expect(map['bookingType'], equals('openJoin'));
      expect(map['rentBall'], isTrue);
      expect(map['deposit_paid'], equals(50.0));
      expect(map['isPaid'], isTrue);
      expect(map['needs_deposit'], isTrue);

      final revived = BookingDraft.fromMap(map);
      expect(revived.stadiumId, equals(draft.stadiumId));
      expect(revived.stadiumName, equals(draft.stadiumName));
      expect(revived.bookingType, equals(BookingType.openJoin));
      expect(revived.rentBall, isTrue);
      expect(revived.depositPaid, equals(50.0));
      expect(revived.isPaid, isTrue);
      expect(revived.needsDeposit, isTrue);
      expect(revived.maxPlayers, equals(10));
    });

    test('unknown restored booking type is rejected, not silently personal', () {
      final draft = BookingDraft(
        stadiumId: 'std-1',
        stadiumName: 'Pitch',
        ownerId: 'owner-1',
        startTime: DateTime.utc(2026, 12, 10, 18),
        endTime: DateTime.utc(2026, 12, 10, 19),
        bookingType: BookingType.challenge,
        isPrivate: false,
        rentBall: false,
        totalPrice: 100.0,
      );
      final saved = draft.toMap();
      saved['bookingType'] = 'unexpected_new_challenge';
      expect(() => BookingDraft.fromMap(saved), throwsFormatException);
    });

    test('restored deposit greater than total is rejected before checkout', () {
      final draft = BookingDraft(
        stadiumId: 'std-1',
        stadiumName: 'Pitch',
        ownerId: 'owner-1',
        startTime: DateTime.utc(2030, 12, 10, 18),
        endTime: DateTime.utc(2030, 12, 10, 19),
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        totalPrice: 100.0,
        depositPaid: 25.0,
      );
      final saved = draft.toMap()..['deposit_paid'] = 150.0;
      expect(() => BookingDraft.fromMap(saved), throwsFormatException);
      expect(BookingDraft.fromMap(draft.toMap()).depositPaid, 25.0);
    });

    test('BookingDraft copyWith updates specific fields', () {
      final now = DateTime(2026, 9, 9, 20, 0);
      final draft = BookingDraft(
        stadiumId: 'std-1',
        stadiumName: 'Old',
        ownerId: 'own-1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 100.0,
      );

      final updated = draft.copyWith(
        stadiumName: 'New Name',
        totalPrice: 150.0,
      );

      expect(updated.stadiumName, equals('New Name'));
      expect(updated.totalPrice, equals(150.0));
      expect(updated.stadiumId, equals('std-1'));
    });
  });
}
