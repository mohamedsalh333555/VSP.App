import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_app/data/models/booking_enums.dart';

void main() {
  group('BookingStatus lifecycle contract', () {
    test('upcoming is a confirmed alias', () {
      expect(BookingStatus.upcoming.canonical, BookingStatus.confirmed);
      expect(BookingStatus.upcoming.toDbValue(), 'confirmed');
      expect(BookingStatus.confirmed.canTransitionTo(BookingStatus.upcoming), isTrue);
    });

    test('pending allows only confirmation, cancellation, expiry or replay', () {
      for (final next in BookingStatus.values) {
        final allowed = {
          BookingStatus.pending,
          BookingStatus.confirmed,
          BookingStatus.upcoming,
          BookingStatus.cancelled,
          BookingStatus.expired,
        }.contains(next);
        expect(BookingStatus.pending.canTransitionTo(next), allowed,
            reason: 'pending -> ${next.name}');
      }
    });

    test('confirmed allows fulfillment, no-show, cancellation or replay', () {
      for (final next in BookingStatus.values) {
        final allowed = {
          BookingStatus.confirmed,
          BookingStatus.upcoming,
          BookingStatus.completed,
          BookingStatus.noShow,
          BookingStatus.cancelled,
        }.contains(next);
        expect(BookingStatus.confirmed.canTransitionTo(next), allowed,
            reason: 'confirmed -> ${next.name}');
      }
    });

    test('terminal states only accept idempotent replays', () {
      for (final from in [
        BookingStatus.completed,
        BookingStatus.noShow,
        BookingStatus.cancelled,
        BookingStatus.expired,
      ]) {
        for (final next in BookingStatus.values) {
          expect(from.canTransitionTo(next), next == from,
              reason: '${from.name} -> ${next.name}');
        }
      }
    });
  });
}
