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
