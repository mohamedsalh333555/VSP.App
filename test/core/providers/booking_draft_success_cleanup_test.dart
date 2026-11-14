import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/providers/booking/booking_draft_storage.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';

class _SuccessRepo extends Fake implements BookingRepository {
  @override
  Future<Booking> createBooking(BookingDraft draft, String userId) async {
    return Booking(
      id: 'server-confirmed',
      stadiumId: draft.stadiumId,
      stadiumName: draft.stadiumName,
      ownerId: draft.ownerId,
      createdByUserId: userId,
      startTime: draft.startTime,
      endTime: draft.endTime,
      bookingType: draft.bookingType,
      isPrivate: draft.isPrivate,
      rentBall: draft.rentBall,
      totalPrice: draft.totalPrice,
      status: BookingStatus.confirmed,
      createdAt: DateTime.now(),
    );
  }
}

BookingDraft _draft() {
  final start = DateTime.now().add(const Duration(days: 1));
  return BookingDraft(
    stadiumId: 'stadium-1',
    stadiumName: 'Test pitch',
    ownerId: 'owner-1',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 220,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a successfully created booking clears persisted checkout draft', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = BookingProvider(repository: _SuccessRepo());
    addTearDown(provider.dispose);

    final draft = _draft();
    provider.setDraft(draft);
    await BookingDraftStorage.save(draft, userId: 'player-A');
    expect(await BookingDraftStorage.restore(userId: 'player-A'), isNotNull);

    final created = await provider.createBookingFromDraft('player-A');
    expect(created?.id, 'server-confirmed');
    expect(provider.currentDraft, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(await BookingDraftStorage.restore(userId: 'player-A'), isNull);
  });
}
