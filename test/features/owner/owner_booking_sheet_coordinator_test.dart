import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/owner_repository.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/booking_sheet/owner_booking_sheet_coordinator.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class MockOwnerRepo extends OwnerRepository {
  bool cashConfirmed = false;
  bool matchExtended = false;

  @override
  Future<dynamic> confirmCashBookingAtomic({
    required String bookingId,
    required String ownerId,
    required double totalPrice,
  }) async {
    cashConfirmed = true;
    return {'success': true};
  }

  @override
  Future<void> extendBookingEndTime({
    required String bookingId,
    required DateTime newEndTime,
  }) async {
    matchExtended = true;
  }
}

void main() {
  final testStadium = Stadium(
    id: 'stadium_1',
    name: 'Al-Ahly Pitch',
    location: 'Cairo, Egypt',
    imageUrl: 'https://example.com/stadium.png',
    type: '5v5',
    size: 'Medium',
    baths: 2,
    cafeteria: 1,
    playersPerTeam: 5,
    totalFieldCapacity: 10,
    pricePerHour: 200,
    basePrice: 200,
    area: 'Cairo',
    openingTime: '08:00',
    closingTime: '23:00',
    isSplitShift: false,
    breakStartTime: '14:00',
    breakEndTime: '16:00',
    ownerId: 'owner_123',
  );

  final testBooking = Booking(
    id: 'booking_123',
    stadiumId: 'stadium_1',
    stadiumName: 'Al-Ahly Pitch',
    createdByUserId: 'owner_123',
    ownerId: 'owner_123',
    bookingType: BookingType.personal,
    startTime: DateTime(2026, 9, 10, 18, 0),
    endTime: DateTime(2026, 9, 10, 19, 0),
    totalPrice: 200,
    depositPaid: 50,
    isPaid: false,
    status: BookingStatus.confirmed,
    createdAt: DateTime(2026, 9, 1),
    isPrivate: false,
    rentBall: true,
    paymentMethod: 'cash',
  );

  group('OwnerBookingSheetCoordinator Tests', () {
    testWidgets('confirmCashPayment calls atomic repository and toggles loading', (tester) async {
      final mockRepo = MockOwnerRepo();
      final loadingStates = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OwnerBookingSheetCoordinator.confirmCashPayment(
                    context: context,
                    parentContext: context,
                    booking: testBooking,
                    selectedStadium: testStadium,
                    isArabic: false,
                    setLoading: (v) => loadingStates.add(v),
                    ownerRepository: mockRepo,
                    currentUserId: 'owner_123',
                  );
                },
                child: const Text('Confirm Cash'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Confirm Cash'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(loadingStates.first, isTrue);
      expect(mockRepo.cashConfirmed, isTrue);
    });

    testWidgets('extendOngoingMatch extends booking end time by 30 mins', (tester) async {
      final mockRepo = MockOwnerRepo();
      final loadingStates = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OwnerBookingSheetCoordinator.extendOngoingMatch(
                    context: context,
                    parentContext: context,
                    booking: testBooking,
                    isArabic: false,
                    setLoading: (v) => loadingStates.add(v),
                    ownerRepository: mockRepo,
                  );
                },
                child: const Text('Extend Match'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Extend Match'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(loadingStates.first, isTrue);
      expect(mockRepo.matchExtended, isTrue);
    });
  });
}
