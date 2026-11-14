import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_snapshot_resolver.dart';

Stadium venue(String id, String name) => Stadium(
      id: id,
      name: name,
      location: 'Aswan',
      imageUrl: '',
      images: const [],
      type: 'Football',
      size: '5 VS 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 100,
      area: 'Aswan',
      isVerified: true,
    );

AsyncSnapshot<List<Map<String, dynamic>>> live(Map<String, dynamic> row) =>
    AsyncSnapshot.withData(ConnectionState.active, [row]);

void main() {
  test('retains the last valid details but blocks booking on errors and retry',
      () {
    final resolver = StadiumSnapshotResolver();
    final route = venue('venue-a', 'Old route name');
    final fresh = live({...route.toMap(), 'id': route.id, 'name': 'Live name'});
    final verified = resolver.resolve(routeStadium: route, snapshot: fresh);
    expect(verified.stadium.name, 'Live name');
    expect(verified.canBook, isTrue);

    final offline = resolver.resolve(
      routeStadium: route,
      snapshot: AsyncSnapshot<List<Map<String, dynamic>>>.withError(
        ConnectionState.active, StateError('offline')),
    );
    expect(offline.stadium.name, 'Live name');
    expect(offline.canBook, isFalse);

    final refreshing = resolver.resolve(
      routeStadium: route,
      snapshot: AsyncSnapshot.withData(ConnectionState.waiting,
          <Map<String, dynamic>>[{'id': route.id, 'name': 'Stale row'}]),
    );
    expect(refreshing.stadium.name, 'Live name');
    expect(refreshing.canBook, isFalse);

    final malformed = resolver.resolve(
      routeStadium: route,
      snapshot: live({'id': route.id, 'players_per_team': 'bad'}),
    );
    expect(malformed.parseFailed, isTrue);
    expect(malformed.stadium.name, 'Live name');
    expect(malformed.canBook, isFalse);

    final removed = resolver.resolve(
      routeStadium: route,
      snapshot: const AsyncSnapshot.withData(
          ConnectionState.active, <Map<String, dynamic>>[]),
    );
    expect(removed.canBook, isFalse);
  });

  test('rejects another venue row and clears cached details on route switch',
      () {
    final resolver = StadiumSnapshotResolver();
    final a = venue('venue-a', 'Venue A');
    final b = venue('venue-b', 'Venue B');
    resolver.resolve(routeStadium: a, snapshot: live({...a.toMap(), 'id': a.id}));

    final switched = resolver.resolve(
      routeStadium: b,
      snapshot: AsyncSnapshot.withData(ConnectionState.waiting,
          <Map<String, dynamic>>[{'id': a.id, 'name': 'Venue A'}]),
    );
    expect(switched.stadium.name, 'Venue B');
    expect(switched.canBook, isFalse);

    final wrongRow = resolver.resolve(
      routeStadium: b,
      snapshot: live({...a.toMap(), 'id': a.id}),
    );
    expect(wrongRow.parseFailed, isTrue);
    expect(wrongRow.stadium.name, 'Venue B');
    expect(wrongRow.canBook, isFalse);

    final current = resolver.resolve(
      routeStadium: b,
      snapshot: live({...b.toMap(), 'id': b.id}),
    );
    expect(current.canBook, isTrue);
  });
}
