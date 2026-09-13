import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/constants/egypt_governorates.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_location_geocoder.dart';

void main() {
  group('StadiumLocationGeocoder Unit Tests', () {
    test('getCoordinatesForGovernorate returns accurate coordinates for known governorates', () {
      final cairo = StadiumLocationGeocoder.getCoordinatesForGovernorate('Cairo');
      expect(cairo.latitude, closeTo(30.0444, 0.001));
      expect(cairo.longitude, closeTo(31.2357, 0.001));

      final alex = StadiumLocationGeocoder.getCoordinatesForGovernorate('Alexandria');
      expect(alex.latitude, closeTo(31.2001, 0.001));
      expect(alex.longitude, closeTo(29.9187, 0.001));

      final luxor = StadiumLocationGeocoder.getCoordinatesForGovernorate('Luxor');
      expect(luxor.latitude, closeTo(25.6872, 0.001));
      expect(luxor.longitude, closeTo(32.6396, 0.001));
    });

    test('getCoordinatesForGovernorate falls back to Cairo for unknown, empty, or null governorates', () {
      final nullGov = StadiumLocationGeocoder.getCoordinatesForGovernorate(null);
      expect(nullGov.latitude, closeTo(30.0444, 0.001));

      final emptyGov = StadiumLocationGeocoder.getCoordinatesForGovernorate('');
      expect(emptyGov.latitude, closeTo(30.0444, 0.001));

      final unknownGov = StadiumLocationGeocoder.getCoordinatesForGovernorate('Atlantis');
      expect(unknownGov.latitude, closeTo(30.0444, 0.001));
    });

    test('searchLocation returns empty list for blank query', () async {
      final results = await StadiumLocationGeocoder.searchLocation('   ', 'ar');
      expect(results, isEmpty);
    });

    test('searchLocation matches governorate names locally with accurate coordinates', () async {
      final resultsAr = await StadiumLocationGeocoder.searchLocation('إسكندرية', 'ar');
      expect(resultsAr.isNotEmpty, isTrue);
      final alexMatch = resultsAr.firstWhere((r) => r['governorate'] == 'Alexandria');
      expect(alexMatch['lat'], closeTo(31.2001, 0.001));
      expect(alexMatch['lon'], closeTo(29.9187, 0.001));
      expect(alexMatch['display_name'], contains('الإسكندرية'));

      final resultsEn = await StadiumLocationGeocoder.searchLocation('Giza', 'en');
      expect(resultsEn.isNotEmpty, isTrue);
      final gizaMatch = resultsEn.firstWhere((r) => r['governorate'] == 'Giza');
      expect(gizaMatch['lat'], closeTo(30.0131, 0.001));
      expect(gizaMatch['lon'], closeTo(31.2089, 0.001));
    });

    test('LocationResult stores coordinates and resolved metadata correctly', () {
      const loc = LocationResult(
        latitude: 30.05,
        longitude: 31.25,
        address: 'شارع النزهة، مصر الجديدة',
        governorate: 'Cairo',
      );
      expect(loc.latitude, 30.05);
      expect(loc.longitude, 31.25);
      expect(loc.governorate, 'Cairo');
    });

    test('findClosestGovernorate resolves Aswan coordinates accurately', () {
      final gov = EgyptGovernorates.findClosestGovernorate(24.0889, 32.8998);
      expect(gov, equals('Aswan'));
    });

    test('resolveGovernorateWithCoordinates rejects distant Red Sea reading for Aswan coordinates', () {
      // Simulating cell tower misattribution in Aswan: coordinates are in Aswan, but raw geocode string says Red Sea
      final resolved = EgyptGovernorates.resolveGovernorateWithCoordinates(
        lat: 24.0889,
        lng: 32.8998,
        rawGeocodeName: 'Red Sea Governorate',
      );
      // Because (24.0889, 32.8998) is >400km away from Red Sea center, it must fall back to Aswan!
      expect(resolved, equals('Aswan'));
    });
  });
}
