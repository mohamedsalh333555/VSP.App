import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  test('live snake-case is_blocked is decoded for player booking gate', () {
    final blocked = Stadium.fromFirestore(
      {
        'name': 'Synthetic Aswan Venue',
        'is_verified': true,
        'is_blocked': true,
        'opening_time': '16:00',
        'closing_time': '23:00',
      },
      'synthetic_blocked_stadium',
    );
    expect(blocked.isVerified, isTrue);
    expect(blocked.isBlocked, isTrue);
  });

  test('camel-case isBlocked is supported and an absent flag is safe', () {
    final alternate = Stadium.fromFirestore(
      {'isBlocked': true},
      'synthetic_camel_case_stadium',
    );
    final unblocked = Stadium.fromFirestore(
      {'is_verified': true, 'is_blocked': false},
      'synthetic_unblocked_stadium',
    );
    expect(alternate.isBlocked, isTrue);
    expect(unblocked.isBlocked, isFalse);
  });

  test('future emergency closure blocks live booking; an expired one does not', () {
    final active = Stadium.fromFirestore(
      {
        'is_verified': true,
        'is_blocked': false,
        'maintenance_until':
            DateTime.now().toUtc().add(const Duration(days: 10)).toIso8601String(),
      },
      'synthetic_active_maintenance',
    );
    final ended = Stadium.fromFirestore(
      {
        'is_verified': true,
        'is_blocked': false,
        'maintenance_until':
            DateTime.now().toUtc().subtract(const Duration(days: 10)).toIso8601String(),
      },
      'synthetic_expired_maintenance',
    );
    expect(active.isUnderMaintenance, isTrue);
    expect(ended.isUnderMaintenance, isFalse);
  });

}
