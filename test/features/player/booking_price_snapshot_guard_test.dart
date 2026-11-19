import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_price_snapshot_guard.dart';

Stadium venue({
  String id = 'pitch-1',
  double price = 320,
  double ballPrice = 30,
  double deposit = 50,
  bool needsDeposit = true,
  bool verified = true,
}) => Stadium(
      id: id,
      name: 'Nile Pitch',
      location: 'Aswan',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: price,
      ballPrice: ballPrice,
      area: 'Aswan',
      depositAmount: deposit,
      needsDeposit: needsDeposit,
      isVerified: verified,
    );

void main() {
  test('accepts an unchanged server quote for selected half hours and ball', () {
    expect(
      BookingPriceSnapshotGuard.matches(
        displayed: venue(),
        latest: venue(),
        halfHourSlots: 3,
        rentBall: true,
        displayedTotal: 510,
      ),
      isTrue,
    );
  });

  test('rejects an owner price edit before payment or cash confirmation', () {
    expect(
      BookingPriceSnapshotGuard.matches(
        displayed: venue(),
        latest: venue(price: 400),
        halfHourSlots: 3,
        rentBall: true,
        displayedTotal: 510,
      ),
      isFalse,
    );
  });

  test('rejects changed deposit and ball rental quote', () {
    for (final latest in [venue(deposit: 70), venue(ballPrice: 40)]) {
      expect(
        BookingPriceSnapshotGuard.matches(
          displayed: venue(),
          latest: latest,
          halfHourSlots: 3,
          rentBall: true,
          displayedTotal: 510,
        ),
        isFalse,
      );
    }
  });

  test('rejects unavailable, unrelated and invalid server rows', () {
    for (final latest in [
      venue(id: 'other-pitch'),
      venue(verified: false),
      venue(price: double.nan),
    ]) {
      expect(
        BookingPriceSnapshotGuard.matches(
          displayed: venue(),
          latest: latest,
          halfHourSlots: 2,
          rentBall: false,
          displayedTotal: 320,
        ),
        isFalse,
      );
    }
  });
}
