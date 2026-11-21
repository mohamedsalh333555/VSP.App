import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_stream_freshness.dart';

void main() {
  test('reused prior-day payload is not current availability on stream change', () {
    const oldDayBookings = <String>['prior-day-booking'];

    final disconnected = AsyncSnapshot<List<String>>.withData(
      ConnectionState.none,
      oldDayBookings,
    );
    final waitingWithOldData = AsyncSnapshot<List<String>>.withData(
      ConnectionState.waiting,
      oldDayBookings,
    );

    // StreamBuilder deliberately carries the old data through both states.
    expect(disconnected.hasData, isTrue);
    expect(waitingWithOldData.hasData, isTrue);
    expect(BookingStreamFreshness.isAwaitingCurrentStream(disconnected), isTrue);
    expect(BookingStreamFreshness.isAwaitingCurrentStream(waitingWithOldData), isTrue);
  });

  test('only a new stream event removes the freshness loading barrier', () {
    final waitingNoData = const AsyncSnapshot<List<String>>.nothing()
        .inState(ConnectionState.waiting);
    final verifiedEmpty = AsyncSnapshot<List<String>>.withData(
      ConnectionState.active,
      <String>[],
    );
    final completed = AsyncSnapshot<List<String>>.withData(
      ConnectionState.done,
      <String>[],
    );

    expect(BookingStreamFreshness.isAwaitingCurrentStream(waitingNoData), isTrue);
    expect(BookingStreamFreshness.isAwaitingCurrentStream(verifiedEmpty), isFalse);
    expect(BookingStreamFreshness.isAwaitingCurrentStream(completed), isFalse);
  });
}
