import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking coordinators preserve repository Supabase client scope', () {
    final repository = File('lib/core/repositories/booking_repository.dart')
        .readAsStringSync();

    for (final coordinator in [
      'BookingCreationCoordinator',
      'BookingCancellationCoordinator',
      'BookingReconciliationService',
      'BookingScheduleCoordinator',
      'BookingQueryCoordinator',
    ]) {
      expect(
        RegExp('$coordinator' r'\s*\(\s*client:\s*_client')
            .hasMatch(repository),
        isTrue,
        reason: '$coordinator must receive the repository client.',
      );
    }

    for (final path in [
      'lib/core/repositories/booking/booking_creation_coordinator.dart',
      'lib/core/repositories/booking/booking_reconciliation_service.dart',
      'lib/core/repositories/booking/booking_cancellation_coordinator.dart',
      'lib/core/repositories/booking/booking_schedule_coordinator.dart',
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('SupabaseClient get _supabase => _client ?? Supabase.instance.client;'),
        reason: path,
      );
      expect(
        source,
        isNot(contains('await Supabase.instance.client.rpc(')),
        reason: '$path must not bypass the injected client.',
      );
    }
  });
}
