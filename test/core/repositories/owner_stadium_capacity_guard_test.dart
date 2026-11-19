import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/stadium/owner_stadium_capacity_guard.dart';

void main() {
  group('owner stadium capacity fails closed', () {
    test('free owner may add their first venue', () {
      expect(
        () => OwnerStadiumCapacityGuard.requireAllowed({
          'allowed': true,
          'current_count': 0,
          'max_allowed': 1,
          'plan_code': 'basic',
        }),
        returnsNormally,
      );
    });

    test('active Pro owner can add a third venue', () {
      expect(
        () => OwnerStadiumCapacityGuard.requireAllowed({
          'allowed': true,
          'current_count': 2,
          'max_allowed': 3,
          'plan_code': 'pro',
        }),
        returnsNormally,
      );
    });

    test('limits reject full free and Pro plans with user feedback', () {
      for (final max in [1, 3]) {
        expect(
          () => OwnerStadiumCapacityGuard.requireAllowed({
            'allowed': false,
            'current_count': max,
            'max_allowed': max,
            'plan_code': max == 1 ? 'basic' : 'pro',
          }),
          throwsStateError,
        );
      }
    });

    test('unauthorized owner is explicitly rejected', () {
      expect(
        () => OwnerStadiumCapacityGuard.requireAllowed({
          'allowed': false,
          'error': 'UNAUTHORIZED',
        }),
        throwsStateError,
      );
    });

    test('network or unparseable payload can never authorize creation', () {
      for (final data in <Object?>[
        null,
        false,
        true,
        'allowed',
        <String, dynamic>{},
        {'allowed': 'true', 'current_count': 0, 'max_allowed': 1},
        {'allowed': true},
        {'allowed': true, 'current_count': -1, 'max_allowed': 1},
        {'allowed': true, 'current_count': 1, 'max_allowed': 1},
        {'allowed': true, 'current_count': 0, 'max_allowed': 0},
        {'allowed': true, 'current_count': double.nan, 'max_allowed': 3},
        {'allowed': false, 'error': 'UNKNOWN'},
      ]) {
        expect(
          () => OwnerStadiumCapacityGuard.requireAllowed(data),
          throwsStateError,
          reason: 'invalid response must not permit stadium insert: $data',
        );
      }
    });

    test('repository checks server RPC before attempting any stadium insert', () {
      final source =
          File('lib/core/repositories/stadium_repository.dart').readAsStringSync();
      final add = source.substring(
        source.indexOf('Future<String?> addStadium('),
        source.indexOf('// Update stadium', source.indexOf('Future<String?> addStadium(')),
      );
      expect(add, contains("rpc(\n        'check_owner_stadium_limit'"));
      expect(add, contains('OwnerStadiumCapacityGuard.requireAllowed(capacity);'));
      expect(
        add.indexOf('OwnerStadiumCapacityGuard.requireAllowed(capacity);'),
        lessThan(add.indexOf(".from('stadiums')")),
      );
      expect(add, isNot(contains('Skip stadium count validation error')));
      expect(add, contains("if (ownerId.isEmpty)"));
    });
  });
}
