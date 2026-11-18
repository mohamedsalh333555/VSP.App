import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/booking_creation_coordinator.dart';

void main() {
  group('Atomic booking error privacy', () {
    test('known business error codes keep safe, actionable Arabic feedback', () {
      final samples = <String, String>{
        'CHALLENGE_CODE_INVALID_OR_USED': 'كود التحدي',
        'CALLER_NOT_A_CAPTAIN': 'كابتن',
        'CANNOT_CHALLENGE_OWN_TEAM': 'نفسه',
        'OPPONENT_TEAM_NOT_FOUND': 'المنافس',
        'SLOT_LOCKED_OR_TAKEN': 'محجوز',
        'IDEMPOTENCY_KEY_CONFLICT': 'طلب',
      };
      for (final entry in samples.entries) {
        final actual = BookingCreationCoordinator.safeRpcFailureMessage({
          'success': false,
          'code': entry.key,
          'message': 'INTERNAL ERROR: email=secret@example.com',
        });
        expect(actual, contains(entry.value), reason: entry.key);
        expect(actual, isNot(contains('secret@example.com')));
        expect(actual, isNot(contains('INTERNAL')));
      }
    });

    test('price mismatch remains a safe internal translation sentinel', () {
      final actual = BookingCreationCoordinator.safeRpcFailureMessage({
        'code': 'PRICE_MISMATCH',
        'message': 'private sql: booking_123',
      });
      expect(actual, 'PRICE_MISMATCH');
    });

    test('database error codes and private details stay generic', () {
      for (final rawCode in ['23505', '42501', 'P0001', 'INTERNAL_DB_ERROR']) {
        final actual = BookingCreationCoordinator.safeRpcFailureMessage({
          'code': rawCode,
          'message': 'select * from auth.users where phone=01001234567',
        });
        expect(actual, contains('تعذر إتمام الحجز'));
        expect(actual, isNot(contains('auth.users')));
        expect(actual, isNot(contains('01001234567')));
      }
    });

    test('unknown codes and raw provider messages are not exposed', () {
      const privateData = 'customer@example.com 01001234567 token=secret';
      for (final response in <Map<String, dynamic>>[
        {'error': privateData},
        {'code': 'UNKNOWN_SQL_EXCEPTION', 'message': privateData},
        {'code': null, 'message': privateData},
        {'code': 999, 'error': privateData},
        {'code': '', 'error': privateData},
        {'code': 'PAYMENT_ROLE_BYPASS', 'message': privateData},
      ]) {
        final actual = BookingCreationCoordinator.safeRpcFailureMessage(response);
        expect(actual, isNot(contains(privateData)), reason: response.toString());
        expect(actual, isNot(contains('01001234567')));
        expect(actual, isNot(contains('token')));
        expect(actual, contains('تعذر إتمام الحجز'));
      }
    });

    test('legacy known error code is safe without using error message', () {
      final actual = BookingCreationCoordinator.safeRpcFailureMessage({
        'error': 'SLOT_LOCKED_OR_TAKEN',
        'message': 'internal venue-id-123',
      });
      expect(actual, contains('محجوز'));
      expect(actual, isNot(contains('venue-id-123')));
    });
  });
}
