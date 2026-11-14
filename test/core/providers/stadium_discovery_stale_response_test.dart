import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';
import 'package:vsp_application/data/models.dart';

class _DelayedStadiumRepository extends StadiumRepository {
  final requests = <String, List<Completer<Map<String, dynamic>>>>{};

  @override
  Future<Map<String, dynamic>> getStadiumsPaginated({
    int limit = 10,
    dynamic startAfter,
    String? governorate,
    String? sportType,
    String? pitchSize,
    List<String>? sportTypes,
    List<String>? pitchSizes,
    double? minPrice,
    double? maxPrice,
    bool? noDepositOnly,
    List<String>? amenities,
    String? quickFilter,
    String? floorType,
    String? searchQuery,
    String? sortBy,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    requests.putIfAbsent(governorate ?? 'All', () => []).add(completer);
    return completer.future;
  }

  Completer<Map<String, dynamic>> request(String governorate, int index) =>
      requests[governorate]![index];
}

Stadium _stadium(String id) => Stadium(
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
    );

Map<String, dynamic> _page(List<Stadium> rows) => {
      'items': rows,
      'lastDoc': rows.length,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new governorate wins over late previous-governorate response', () async {
    final backend = _DelayedStadiumRepository();
    final provider = StadiumProvider(repository: backend);
    addTearDown(provider.dispose);

    provider.applyGovernorateFilter('Aswan');
    provider.applyGovernorateFilter('Cairo');

    backend.request('Cairo', 0).complete(_page([_stadium('cairo-pitch')]));
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'cairo-pitch');

    backend.request('Aswan', 0).complete(_page([_stadium('stale-aswan')]));
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'cairo-pitch');
    expect(provider.selectedGovernorate, 'Cairo');
  });

  test('switching governorates immediately clears old results', () async {
    final backend = _DelayedStadiumRepository();
    final provider = StadiumProvider(repository: backend);
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.applyGovernorateFilter('Aswan');
    backend.request('Aswan', 0).complete(_page([_stadium('aswan-pitch')]));
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'aswan-pitch');

    final beforeSwitch = notifications;
    provider.applyGovernorateFilter('Cairo');
    expect(provider.stadiums, isEmpty);
    expect(provider.isLoading, isTrue);
    expect(notifications, greaterThan(beforeSwitch));

    backend.request('Cairo', 0).complete(_page([_stadium('cairo-pitch')]));
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'cairo-pitch');
  });

  test('applying a new server filter clears old results before response',
      () async {
    final backend = _DelayedStadiumRepository();
    final provider = StadiumProvider(repository: backend);
    addTearDown(provider.dispose);

    provider.applyFilters({'location': 'Aswan', 'searchQuery': 'pitch'});
    backend.request('Aswan', 0).complete(_page([_stadium('old-filter')]));
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'old-filter');

    provider.applyFilters({'location': 'Cairo', 'searchQuery': 'arena'});
    expect(provider.stadiums, isEmpty);
    expect(provider.isLoading, isTrue);
    backend.request('Cairo', 0).complete(_page([_stadium('new-filter')]));
    await Future<void>.delayed(Duration.zero);
    expect(provider.stadiums.single.id, 'new-filter');
  });

  test('discovery failure is not presented as verified empty results', () async {
    final backend = _DelayedStadiumRepository();
    final provider = StadiumProvider(repository: backend);
    addTearDown(provider.dispose);

    provider.applyGovernorateFilter('Aswan');
    backend.request('Aswan', 0).completeError(
      StateError('PRIVATE_SUPABASE_REQUEST'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.errorMessage, 'stadium_load_failed');
    expect(provider.stadiums, isEmpty);

    final retry = provider.fetchStadiums(isRefresh: true);
    backend.request('Aswan', 1).complete(_page([_stadium('recovered')]));
    await retry;
    expect(provider.errorMessage, isNull);
    expect(provider.stadiums.single.id, 'recovered');
    expect(provider.hasMore, isFalse);
  });
}
