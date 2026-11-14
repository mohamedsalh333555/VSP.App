import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';
import 'package:vsp_application/data/models.dart';

class _OwnerStreamFixture extends StadiumRepository {
  final Map<String, StreamController<List<Stadium>>> controllers = {};

  StreamController<List<Stadium>> _controller(String ownerId) =>
      controllers.putIfAbsent(
        ownerId,
        () => StreamController<List<Stadium>>.broadcast(),
      );

  @override
  Stream<List<Stadium>> getOwnerStadiums(String ownerId) =>
      _controller(ownerId).stream;

  void emit(String ownerId, List<Stadium> stadiums) =>
      _controller(ownerId).add(stadiums);

  void fail(String ownerId) =>
      _controller(ownerId).addError(StateError('PRIVATE_BACKEND_DETAILS'));

  Future<void> close() async {
    for (final controller in controllers.values) {
      await controller.close();
    }
  }
}

Stadium _stadium(String id, String ownerId) => Stadium(
      id: id,
      name: id,
      location: 'Aswan',
      imageUrl: '',
      type: 'Football',
      size: '5 vs 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 250,
      area: 'Aswan',
      ownerId: ownerId,
    );

void main() {
  test('second realtime update notifies even after initial loading stops',
      () async {
    final source = _OwnerStreamFixture();
    final provider = StadiumProvider(repository: source);
    addTearDown(() async {
      provider.dispose();
      await source.close();
    });
    var changes = 0;
    provider.addListener(() => changes++);

    provider.listenToOwnerStadiums('owner-A');
    expect(provider.isLoading, isTrue);
    source.emit('owner-A', [_stadium('pitch-1', 'owner-A')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.isLoading, isFalse);
    expect(provider.stadiums.single.id, 'pitch-1');
    final afterInitial = changes;

    source.emit('owner-A', [_stadium('pitch-2', 'owner-A')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'pitch-2');
    expect(changes, greaterThan(afterInitial));

    source.fail('owner-A');
    await Future<void>.delayed(Duration.zero);
    expect(provider.errorMessage, 'owner_stadium_sync_failed');
    expect(provider.errorMessage, isNot(contains('PRIVATE_BACKEND_DETAILS')));
    expect(provider.stadiums.single.id, 'pitch-2');
  });

  test('player filters cannot erase the current owner stadiums', () async {
    final fixture = _OwnerStreamFixture();
    final provider = StadiumProvider(repository: fixture);
    addTearDown(() async {
      provider.dispose();
      await fixture.close();
    });

    provider.listenToOwnerStadiums('owner-A');
    fixture.emit('owner-A', [_stadium('owned-pitch', 'owner-A')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'owned-pitch');

    provider.applyGovernorateFilter('Cairo');
    provider.applyFilters({'location': 'Aswan'});
    provider.toggleQuickFilter('no_deposit');
    await provider.clearFilters();
    expect(provider.stadiums.single.id, 'owned-pitch');
    expect(provider.errorMessage, isNull);
  });

  test('switching owners discards the prior owner stadium snapshot', () async {
    final source = _OwnerStreamFixture();
    final provider = StadiumProvider(repository: source);
    addTearDown(() async {
      provider.dispose();
      await source.close();
    });

    provider.listenToOwnerStadiums('owner-A');
    source.emit('owner-A', [_stadium('a', 'owner-A')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'a');

    provider.listenToOwnerStadiums('owner-B');
    expect(provider.stadiums, isEmpty);
    source.emit('owner-A', [_stadium('stale-a', 'owner-A')]);
    source.emit('owner-B', [_stadium('b', 'owner-B')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.ownerId, 'owner-B');
  });
}
