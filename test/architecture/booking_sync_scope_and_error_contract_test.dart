import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final provider = File('lib/core/providers/booking_provider.dart')
      .readAsStringSync();
  final sync = File('lib/core/providers/booking/booking_sync_coordinator.dart')
      .readAsStringSync();
  final stadium = File('lib/core/repositories/stadium_repository.dart')
      .readAsStringSync();

  test('bookings refresh and role changes invalidate older async requests', () {
    final from = provider.indexOf('Future<bool> loadUserBookings(');
    final to = provider.indexOf('/// Cancel a booking', from);
    final scope = provider.substring(from, to);
    expect(scope, contains('++_bookingScopeGeneration'));
    expect(scope, contains('requestGeneration != _bookingScopeGeneration'));
    expect(
      'requestGeneration != _bookingScopeGeneration'.allMatches(scope).length,
      greaterThanOrEqualTo(6),
    );
    expect(scope, contains('_activeUserId = userId;'));
    expect(scope, contains('_activeOwnerId = ownerId;'));
    expect(scope, contains('_userBookings = [];'));
    expect(scope, contains('await _clearDraftOnAccountScopeChange();'));
  });

  test('player and owner sync never expose raw provider errors', () {
    expect(sync, contains('Failed to load bookings'));
    expect(sync, contains('Failed to load owner bookings'));
    expect(sync, isNot(contains('Failed to load bookings: \$e')));
    expect(sync, isNot(contains('Failed to load owner bookings: \$e')));
    expect(sync, isNot(contains('error: \$e')));
    expect(sync, contains('details redacted'));
  });

  test('owner stream errors propagate to the UI rather than disappearing', () {
    final start = stadium.indexOf('Stream<List<Stadium>> getOwnerStadiums(');
    final end = stadium.indexOf('// Add new stadium (Owner)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final stream = stadium.substring(start, end);
    expect(stream, contains('Error.throwWithStackTrace(error, stack);'));
    expect(stream, contains('rethrow;'));
    expect(stream, contains('Initial owner stadium fetch failed (details redacted)'));
    expect(stream, isNot(contains('return <Stadium>[];\n    });')));
    expect(stream, contains('.eq(\'owner_id\', cleanOwnerId)'));
  });
}
