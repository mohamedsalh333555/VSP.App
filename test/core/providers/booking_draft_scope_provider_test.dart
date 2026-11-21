import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';

class _EmptyBookingRepository extends Fake implements BookingRepository {
  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) async => [];

  @override
  Stream<List<Booking>> getUserBookings(String userId) =>
      const Stream<List<Booking>>.empty();

  @override
  Stream<List<Booking>> getOwnerBookings(
    String ownerId, {
    List<String>? stadiumIds,
  }) => const Stream<List<Booking>>.empty();
}

BookingDraft _draft() {
  final start = DateTime.now().add(const Duration(days: 2));
  return BookingDraft(
    stadiumId: 'private-pitch',
    stadiumName: 'Previous session',
    ownerId: 'owner',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 120,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first authenticated account cannot inherit an unscoped in-memory draft',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = BookingProvider(repository: _EmptyBookingRepository());
    addTearDown(provider.dispose);

    provider.setDraft(_draft());
    expect(provider.currentDraft, isNotNull);
    expect(await provider.loadUserBookings('different-user'), isTrue);
    expect(provider.currentDraft, isNull);
  });
}
