import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/screens/booking_confirmation_screen.dart';
import 'package:vsp_application/features/player/services/book_tonight_service.dart';
import 'package:vsp_application/features/player/widgets/home/book_tonight_card.dart';
import 'package:vsp_application/features/player/widgets/home/book_tonight_sheet.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _TestBookingRepository implements BookingRepository {
  _TestBookingRepository([this.bookings = const []]);
  final List<Booking> bookings;

  @override
  Future<List<Booking>> fetchStadiumBookingsDirectly(String stadiumId, DateTime date) async {
    return bookings.where((b) => b.stadiumId == stadiumId).toList();
  }

  @override
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) {
    return Stream.value(bookings.where((b) => b.stadiumId == stadiumId).toList());
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('This test repository method is not configured.');
}

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.isGetter) return null;
    return super.noSuchMethod(i);
  }
}

void main() {
  final testStadium = Stadium(
    id: 'std_tonight_1',
    name: 'Camp Nou Cairo',
    location: 'Nasr City, Cairo',
    ownerId: 'own_tonight',
    imageUrl: 'https://example.com/pitch.jpg',
    type: 'Football',
    size: '5 VS 5',
    baths: 1,
    cafeteria: 1,
    playersPerTeam: 5,
    totalFieldCapacity: 10,
    pricePerHour: 300.0,
    basePrice: 300.0,
    area: '800 m²',
    openingTime: '06:00 PM',
    closingTime: '11:00 PM',
    features: {
      'workingHours': {
        'start': '18:00',
        'end': '23:00',
      },
    },
  );

  group('⚡ Book Tonight Fast-Track Service Tests', () {
    test('extractAvailableSlots forms 1-hour matches correctly for unbooked evening', () {
      final now = DateTime(2026, 9, 9, 17, 0); // 5:00 PM
      final operationalDate = DateTime(2026, 9, 9);

      final slots = BookTonightService.extractAvailableSlots(
        stadium: testStadium,
        existingBookings: [],
        operationalDate: operationalDate,
        now: now,
        isArabic: false,
      );

      // 18:00 to 23:00 = 5 hours = should generate pairs:
      // 18:00-19:00, 19:00-20:00, 20:00-21:00, 21:00-22:00
      expect(slots.isNotEmpty, isTrue);
      expect(slots.first.isOneHour, isTrue);
      expect(slots.first.price, 300.0);
      expect(slots.first.slotKeys.length, 2);
    });

    test('extractAvailableSlots omits booked slot pairs', () {
      final now = DateTime(2026, 9, 9, 17, 0);
      final operationalDate = DateTime(2026, 9, 9);

      // Booking for 18:00 - 19:00
      final booked = Booking(
        id: 'bk_18_19',
        stadiumId: testStadium.id,
        stadiumName: testStadium.name,
        ownerId: testStadium.ownerId,
        createdByUserId: 'user_1',
        startTime: DateTime(2026, 9, 9, 18, 0),
        endTime: DateTime(2026, 9, 9, 19, 0),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 300.0,
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        isPaid: true,
        paymentMethod: 'cash',
        createdAt: now,
      );

      final slots = BookTonightService.extractAvailableSlots(
        stadium: testStadium,
        existingBookings: [booked],
        operationalDate: operationalDate,
        now: now,
        isArabic: true,
      );

      // 18:00 to 19:00 is booked, so the first available match must start at or after 19:00
      expect(slots.any((s) => s.slotKeys.contains('06:00 PM')), isFalse);
      expect(slots.any((s) => s.slotKeys.contains('06:30 PM')), isFalse);
    });

    test('findTonightOffers returns populated offers from the booking repository contract', () async {
      final repository = _TestBookingRepository();
      final service = BookTonightService(bookingRepository: repository);

      final offers = await service.findTonightOffers(
        stadiums: [testStadium],
        isArabic: true,
        currentTime: DateTime(2026, 9, 9, 17, 0),
      );

      expect(offers.length, 1);
      expect(offers.first.stadium.id, testStadium.id);
      expect(offers.first.availableSlots.isNotEmpty, isTrue);
    });
  });

  group('⚡ Book Tonight UI & Widgets Tests', () {
    testWidgets('BookTonightCard renders properly when stadiums are present', (tester) async {
      final stadiumProvider = StadiumProvider();
      stadiumProvider.stadiums.add(testStadium);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChangeNotifierProvider<StadiumProvider>.value(
            value: stadiumProvider,
            child: const Scaffold(
              body: BookTonightCard(),
            ),
          ),
        ),
      );

      expect(find.text('جاهز تلعب الليلة؟'), findsOneWidget);
      expect(find.text('سريع'), findsOneWidget);
    });

    testWidgets('BookTonightSheet renders open slots and navigates with preselected slots', (tester) async {
      final repository = _TestBookingRepository();
      final mockService = BookTonightService(bookingRepository: repository);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
            ChangeNotifierProvider<BookingProvider>(
              create: (_) => BookingProvider(repository: repository),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BookTonightSheet(
                stadiums: [testStadium],
                service: mockService,
                currentTime: DateTime(2026, 9, 9, 17, 0),
              ),
            ),
          ),
        ),
      );

      // Allow async future in initState to finish
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ساعات الليلة الشاغرة'), findsOneWidget);
      expect(find.text('Camp Nou Cairo'), findsOneWidget);

      // Find slot chips
      final inkWells = find.byType(InkWell);
      expect(inkWells, findsWidgets);

      await tester.tap(inkWells.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Successfully navigated to BookingConfirmationScreen
      expect(find.byType(BookingConfirmationScreen), findsOneWidget);
    });
  });
}
