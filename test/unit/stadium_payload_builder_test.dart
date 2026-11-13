import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/stadium/stadium_payload_builder.dart';

void main() {
  group('StadiumPayloadBuilder Unit Tests', () {
    test('formatTimeToHms formats hours, minutes, and seconds properly', () {
      expect(StadiumPayloadBuilder.formatTimeToHms(null), isNull);
      expect(StadiumPayloadBuilder.formatTimeToHms(''), isNull);
      expect(StadiumPayloadBuilder.formatTimeToHms('16'), '16:00:00');
      expect(StadiumPayloadBuilder.formatTimeToHms('16:30'), '16:30:00');
      expect(StadiumPayloadBuilder.formatTimeToHms('08:15:30'), '08:15:30');
    });

    test('only EGP currency is accepted and normalized money stays numeric', () {
      final result = StadiumPayloadBuilder.buildInsertPayload({
        'currency': 'egp',
        'pricePerHour': ' 350.25 ',
        'basePrice': '350.25',
        'depositAmount': '100',
        'needsDeposit': true,
      });
      expect(result['price_per_hour'], 350.25);
      expect(result['base_price'], 350.25);
      expect(result['deposit_amount'], 100);
      expect(result['needs_deposit'], isTrue);
      for (final currency in <String>['USD', 'EUR', '']) {
        expect(
          () => StadiumPayloadBuilder.buildInsertPayload({
            'currency': currency, 'pricePerHour': 200,
          }),
          throwsFormatException,
        );
        expect(
          () => StadiumPayloadBuilder.buildUpdatePayload({
            'currency_code': currency, 'price_per_hour': 200,
          }),
          throwsFormatException,
        );
      }
    });

    test('invalid hourly, base and deposit amounts fail before database insertion', () {
      for (final invalid in <Object?>[
        -1, double.nan, double.infinity, '-12.50', 'invalid', true,
      ]) {
        expect(
          () => StadiumPayloadBuilder.buildInsertPayload({'pricePerHour': invalid}),
          throwsFormatException,
          reason: 'invalid hourly price: $invalid',
        );
        expect(
          () => StadiumPayloadBuilder.buildUpdatePayload({'basePrice': invalid}),
          throwsFormatException,
          reason: 'invalid base price: $invalid',
        );
        expect(
          () => StadiumPayloadBuilder.buildUpdatePayload({'depositAmount': invalid}),
          throwsFormatException,
          reason: 'invalid deposit: $invalid',
        );
      }
    });

    test('required deposit cannot exceed price or be zero', () {
      expect(
        () => StadiumPayloadBuilder.buildInsertPayload({
          'pricePerHour': 250,
          'needsDeposit': true,
          'depositAmount': 251,
        }),
        throwsFormatException,
      );
      expect(
        () => StadiumPayloadBuilder.buildInsertPayload({
          'pricePerHour': 250,
          'needsDeposit': true,
          'depositAmount': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => StadiumPayloadBuilder.buildUpdatePayload({
          'price_per_hour': 250,
          'deposit_amount': 251,
        }),
        throwsFormatException,
      );
      expect(
        () => StadiumPayloadBuilder.buildUpdatePayload({
          'needs_deposit': true,
          'deposit_amount': 0,
        }),
        throwsFormatException,
      );
    });

    test('buildInsertPayload removes restricted keys and formats defaults', () {
      final raw = {
        'name': 'Al-Ahly Pitch',
        'owner_id': 'owner_123',
        'pricePerHour': 250.0,
        'isVerified': true,
        'createdAt': '2026-01-01',
        'isSplitShift': true,
        'breakStartTime': '15:00',
        'breakEndTime': '17:00',
        'seatsCapacity': 6,
      };

      final payload = StadiumPayloadBuilder.buildInsertPayload(raw);

      expect(payload['name'], 'Al-Ahly Pitch');
      expect(payload['owner_id'], 'owner_123');
      expect(payload['price_per_hour'], 250.0);
      expect(payload['base_price'], 250.0);
      expect(payload['is_verified'], isFalse); // System always enforces unverified until audited
      expect(payload.containsKey('isVerified'), isFalse);
      expect(payload.containsKey('createdAt'), isFalse);
      expect(payload['is_split_shift'], isTrue);
      expect(payload['break_start_time'], '15:00:00');
      expect(payload['break_end_time'], '17:00:00');
      expect(payload['players_per_team'], 6);
      expect(payload['total_field_capacity'], 12);
    });

    test('owner edits cannot smuggle moderator flags or review scores', () {
      final payload = StadiumPayloadBuilder.buildUpdatePayload({
        'name': 'Updated Pitch',
        'ownerId': 'another_owner',
        'owner_id': 'another_owner',
        'isVerified': true,
        'is_verified': true,
        'isBlocked': false,
        'is_blocked': false,
        'rating': 5.0,
        'reviewsCount': 100000,
        'reviews_count': 100000,
        'is_deleted_by_owner': true,
      });

      expect(payload['name'], 'Updated Pitch');
      expect(payload['is_deleted_by_owner'], isTrue);
      for (final forbidden in <String>[
        'ownerId',
        'owner_id',
        'is_verified',
        'is_blocked',
        'rating',
        'reviews_count',
      ]) {
        expect(payload.containsKey(forbidden), isFalse,
            reason: 'Owner should not be able to edit protected field $forbidden');
      }
    });

    test('buildUpdatePayload strips ownerId and synchronizes base_price', () {
      final updateData = {
        'ownerId': 'malicious_owner_spoof',
        'price_per_hour': 350.0,
        'location': 'Zayed, Giza',
        'isSplitShift': false,
      };

      final payload = StadiumPayloadBuilder.buildUpdatePayload(updateData);

      expect(payload.containsKey('ownerId'), isFalse);
      expect(payload.containsKey('owner_id'), isFalse);
      expect(payload['price_per_hour'], 350.0);
      expect(payload['base_price'], 350.0);
      expect(payload['location'], 'Zayed, Giza');
      expect(payload['is_split_shift'], isFalse);
      expect(payload['break_start_time'], isNull);
      expect(payload['break_end_time'], isNull);
    });
  });
}
