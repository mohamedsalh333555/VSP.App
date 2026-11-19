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
  test('live maintenance and invalid price or deposit disable booking', () {
    final route = venue('venue-a', 'Pitch A');
    final cases = <Map<String, dynamic>>[
      {'maintenance_until': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String()},
      {'price_per_hour': 0, 'pricePerHour': 0, 'base_price': 0, 'basePrice': 0},
      {'price_per_hour': -1, 'pricePerHour': -1, 'base_price': -1, 'basePrice': -1},
      {'price_per_hour': 'NaN', 'pricePerHour': 'NaN', 'base_price': 'NaN', 'basePrice': 'NaN'},
      {'price_per_hour': 100, 'pricePerHour': 100, 'base_price': 0, 'basePrice': 0},
      {'needs_deposit': true, 'needsDeposit': true, 'deposit_amount': 0, 'depositAmount': 0},
      {'needs_deposit': true, 'needsDeposit': true, 'deposit_amount': -1, 'depositAmount': -1},
      {'needs_deposit': false, 'needsDeposit': false, 'deposit_amount': 'NaN', 'depositAmount': 'NaN'},
    ];
    for (final fields in cases) {
      final result = StadiumSnapshotResolver().resolve(
        routeStadium: route,
        snapshot: live({...route.toMap(), 'id': route.id, ...fields}),
      );
      expect(result.canBook, isFalse, reason: 'Unverified booking fields: $fields');
    }
    final bookable = StadiumSnapshotResolver().resolve(
      routeStadium: route,
      snapshot: live({
        ...route.toMap(), 'id': route.id, 'needs_deposit': true,
        'needsDeposit': true, 'deposit_amount': 20, 'depositAmount': 20,
      }),
    );
    expect(bookable.canBook, isTrue);
  });

  test('duplicate venue source rows are ambiguous even when first is valid', () {
    final route = venue('venue-a', 'Pitch A');
    final resolver = StadiumSnapshotResolver();
    final good = {...route.toMap(), 'id': route.id};
    final first = resolver.resolve(routeStadium: route, snapshot: live(good));
    expect(first.canBook, isTrue);
    final ambiguous = resolver.resolve(
      routeStadium: route,
      snapshot: AsyncSnapshot.withData(ConnectionState.active, [
        good, {...good, 'name': 'Different venue', 'price_per_hour': 1},
      ]),
    );
    expect(ambiguous.canBook, isFalse);
    expect(ambiguous.parseFailed, isTrue);
    expect(ambiguous.stadium.name, first.stadium.name);
  });


  test('snake_case base price from SQL cannot be replaced by hourly rent', () {
    final route = venue('venue-a', 'Pitch A');
    final sqlRow = <String, dynamic>{...route.toMap(), 'id': route.id}
      ..remove('pricePerHour')
      ..remove('basePrice')
      ..remove('isVerified')
      ..remove('needsDeposit')
      ..remove('depositAmount');
    sqlRow['base_price'] = 0;
    final rejected = StadiumSnapshotResolver().resolve(
      routeStadium: route, snapshot: live(sqlRow),
    );
    expect(rejected.stadium.basePrice, 0);
    expect(rejected.canBook, isFalse);

    sqlRow['base_price'] = 120;
    final accepted = StadiumSnapshotResolver().resolve(
      routeStadium: route, snapshot: live(sqlRow),
    );
    expect(accepted.stadium.basePrice, 120);
    expect(accepted.stadium.pricePerHour, 100);
    expect(accepted.canBook, isTrue);
  });

  test('mixed booking aliases never silently hide conflicting live values', () {
    final route = venue('venue-a', 'Pitch A');
    final original = <String, dynamic>{...route.toMap(), 'id': route.id};
    final conflicting = <Map<String, dynamic>>[
      {'price_per_hour': 0},
      {'pricePerHour': 0},
      {'base_price': 0},
      {'basePrice': 0},
      {'is_verified': false},
      {'needs_deposit': true},
      {'deposit_amount': 50},
      {'is_blocked': true, 'isBlocked': false},
    ];
    for (final override in conflicting) {
      final result = StadiumSnapshotResolver().resolve(
        routeStadium: route, snapshot: live({...original, ...override}),
      );
      expect(result.parseFailed, isTrue, reason: 'Conflicting aliases: $override');
      expect(result.canBook, isFalse, reason: 'Conflicting aliases: $override');
    }
    final equivalent = StadiumSnapshotResolver().resolve(
      routeStadium: route,
      snapshot: live({...original, 'price_per_hour': '100',
        'base_price': '100', 'deposit_amount': '0'}),
    );
    expect(equivalent.parseFailed, isFalse);
    expect(equivalent.canBook, isTrue);
  });

}
