import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/no_show_dispute_service.dart';

void main() {
  group('NoShowDisputeService Unit Tests', () {
    test('isAccuracyAcceptable enforces 50m threshold', () {
      expect(NoShowDisputeService.isAccuracyAcceptable(10.0), isTrue);
      expect(NoShowDisputeService.isAccuracyAcceptable(49.9), isTrue);
      expect(NoShowDisputeService.isAccuracyAcceptable(50.0), isTrue);
      expect(NoShowDisputeService.isAccuracyAcceptable(50.1), isFalse);
      expect(NoShowDisputeService.isAccuracyAcceptable(120.0), isFalse);
    });

    test('isWithinStadiumRadius enforces 200m proximity threshold', () {
      expect(NoShowDisputeService.isWithinStadiumRadius(15.0), isTrue);
      expect(NoShowDisputeService.isWithinStadiumRadius(199.9), isTrue);
      expect(NoShowDisputeService.isWithinStadiumRadius(200.0), isTrue);
      expect(NoShowDisputeService.isWithinStadiumRadius(200.1), isFalse);
      expect(NoShowDisputeService.isWithinStadiumRadius(500.0), isFalse);
    });

    test('calculateDistance returns near 0 for identical coordinates', () {
      final dist = NoShowDisputeService.calculateDistance(
        playerLat: 30.0444,
        playerLng: 31.2357,
        stadiumLat: 30.0444,
        stadiumLng: 31.2357,
      );
      expect(dist, closeTo(0.0, 0.01));
    });

    test('calculateDistance computes distance accurately between known points', () {
      // Cairo Tower (30.0459, 31.2243) to Tahrir Square (30.0444, 31.2357) ~ 1.1km
      final dist = NoShowDisputeService.calculateDistance(
        playerLat: 30.0459,
        playerLng: 31.2243,
        stadiumLat: 30.0444,
        stadiumLng: 31.2357,
      );
      expect(dist, greaterThan(1000.0));
      expect(dist, lessThan(1300.0));
    });
  });
}
