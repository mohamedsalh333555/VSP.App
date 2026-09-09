import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_location_geocoder.dart';

void main() {
  group('StadiumLocationGeocoder Tests', () {
    test('searchLocation returns empty list for empty or whitespace query', () async {
      expect(await StadiumLocationGeocoder.searchLocation('', 'ar'), isEmpty);
      expect(await StadiumLocationGeocoder.searchLocation('   ', 'en'), isEmpty);
    });

    test('searchLocation finds Egyptian governorates by local lookup', () async {
      final resultsCairo = await StadiumLocationGeocoder.searchLocation('Cairo', 'en');
      expect(resultsCairo, isNotEmpty);
      expect(resultsCairo.first['governorate'], 'Cairo');

      final resultsAlexAr = await StadiumLocationGeocoder.searchLocation('الإسكندرية', 'ar');
      expect(resultsAlexAr, isNotEmpty);
      expect(resultsAlexAr.first['governorate'], 'Alexandria');
    });

    test('LocationResult stores correct coordinates and address', () {
      const loc = LocationResult(
        latitude: 30.0444,
        longitude: 31.2357,
        address: 'Tahrir Square, Cairo, Egypt',
        governorate: 'Cairo',
      );
      expect(loc.latitude, 30.0444);
      expect(loc.longitude, 31.2357);
      expect(loc.address, 'Tahrir Square, Cairo, Egypt');
      expect(loc.governorate, 'Cairo');
    });
  });
}
