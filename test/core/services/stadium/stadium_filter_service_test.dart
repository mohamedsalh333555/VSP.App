import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/services/stadium/stadium_filter_service.dart';

void main() {
  group('StadiumFilterService Unit Tests', () {
    final stadiumA = Stadium(
      id: 's1',
      name: 'City Field',
      location: 'Nasr City',
      governorate: 'Cairo',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 1,
      cafeteria: 1,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 400.0,
      basePrice: 400.0,
      area: '800 m²',
      rating: 4.8,
      closingTime: '02:00 AM',
      lat: 30.05,
      lng: 31.35,
      needsDeposit: false,
      depositAmount: 0.0,
      hasJerash: true,
      hasBall: true,
      hasSeats: true,
      features: {
        'bathOption': 'Yes',
        'garage': true,
      },
    );

    final stadiumB = Stadium(
      id: 's2',
      name: 'Sunset Arena',
      location: 'Maadi',
      governorate: 'Cairo',
      imageUrl: '',
      type: 'Padel',
      size: '2 VS 2',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 2,
      totalFieldCapacity: 4,
      pricePerHour: 700.0,
      basePrice: 700.0,
      area: '400 m²',
      rating: 4.5,
      closingTime: '11:00 PM',
      lat: 29.96,
      lng: 31.28,
      needsDeposit: true,
      depositAmount: 150.0,
      features: {
        'workingHours': {'end': '11:00 PM'},
      },
    );

    final stadiumC = Stadium(
      id: 's3',
      name: 'Giza Sports Hub',
      location: 'Dokki',
      governorate: 'Giza',
      imageUrl: '',
      type: 'Basketball',
      size: '5 VS 5',
      baths: 1,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 300.0,
      basePrice: 300.0,
      area: '600 m²',
      rating: 4.1,
      closingTime: '10:00 PM',
      lat: 30.04,
      lng: 31.21,
      needsDeposit: true,
      depositAmount: 50.0,
      features: {
        'workingHours': {'end': '01:00 AM'},
        'changingRoom': true,
      },
    );

    final list = [stadiumA, stadiumB, stadiumC];

    test('isNightShiftStadium detects closing times with AM and workingHours', () {
      expect(StadiumFilterService.isNightShiftStadium(stadiumA), isTrue);
      expect(StadiumFilterService.isNightShiftStadium(stadiumB), isFalse);
      expect(StadiumFilterService.isNightShiftStadium(stadiumC), isTrue);
    });

    test('checkAmenity detects amenities from fields and dynamic features', () {
      expect(StadiumFilterService.checkAmenity(stadiumA, 'No Deposit Needed'), isTrue);
      expect(StadiumFilterService.checkAmenity(stadiumB, 'No Deposit Needed'), isFalse);

      expect(StadiumFilterService.checkAmenity(stadiumA, 'Showers & Baths'), isTrue);
      expect(StadiumFilterService.checkAmenity(stadiumB, 'Showers & Baths'), isFalse);

      expect(StadiumFilterService.checkAmenity(stadiumC, 'Changing Rooms'), isTrue);
      expect(StadiumFilterService.checkAmenity(stadiumA, 'Night Floodlights'), isTrue);
      expect(StadiumFilterService.checkAmenity(stadiumA, 'Garage & Parking'), isTrue);
      expect(StadiumFilterService.checkAmenity(stadiumA, 'Ball Provided'), isTrue);
      expect(StadiumFilterService.checkAmenity(stadiumA, 'Spectator Seats'), isTrue);
    });

    test('searchStadiums matches name and location case-insensitively', () {
      final res1 = StadiumFilterService.searchStadiums(list, 'sunset');
      expect(res1.length, 1);
      expect(res1.first.id, 's2');

      final res2 = StadiumFilterService.searchStadiums(list, 'dokki');
      expect(res2.length, 1);
      expect(res2.first.id, 's3');

      final resEmpty = StadiumFilterService.searchStadiums(list, '');
      expect(resEmpty.length, 3);
    });

    test('filterByLocation filters by location keyword', () {
      final res = StadiumFilterService.filterByLocation(list, 'nasr');
      expect(res.length, 1);
      expect(res.first.id, 's1');

      expect(StadiumFilterService.filterByLocation(list, '').length, 3);
    });

    test('filterByPriceRange filters stadiums within range', () {
      final res = StadiumFilterService.filterByPriceRange(list, 300.0, 500.0);
      expect(res.map((s) => s.id).toList(), ['s1', 's3']);
    });

    test('applyQuickFilter filters night_shift and no_deposit correctly', () {
      final night = StadiumFilterService.applyQuickFilter(list, 'night_shift');
      expect(night.map((s) => s.id).toSet(), {'s1', 's3'});

      final noDep = StadiumFilterService.applyQuickFilter(list, 'no_deposit');
      expect(noDep.map((s) => s.id).toList(), ['s1']);

      final all = StadiumFilterService.applyQuickFilter(list, null);
      expect(all.length, 3);
    });

    test('sortStadiumsByDistance sorts by distance from user position', () {
      // User near Dokki / Giza (30.04, 31.21)
      final sorted = List<Stadium>.from(list);
      StadiumFilterService.sortStadiumsByDistance(sorted, 30.04, 31.21);

      expect(sorted.first.id, 's3');
    });

    test('getAvailableSportTypes returns unique registered sports contained in active list', () {
      final sports = StadiumFilterService.getAvailableSportTypes(list, ['Football', 'Padel', 'Tennis']);
      expect(sports.toSet(), {'Football', 'Padel'});
    });
  });
}
