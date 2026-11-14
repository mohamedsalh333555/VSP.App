import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/core/services/auth_service.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/screens/bookings_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _AuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
}

class _AuthProvider extends AuthProvider {
  _AuthProvider() : super(authService: _AuthService());

  @override
  User? get currentUser => User.fromJson({
        'id': 'player-1',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'player-1@test.invalid',
        'created_at': '2026-01-01T00:00:00.000Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      });

  @override
  bool get isOwner => false;

  @override
  bool get isPlayer => true;
}

class _BookingRepository extends Fake implements BookingRepository {
  _BookingRepository(this.bookings);

  final List<Booking> bookings;

  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) async {
    expect(userId, 'player-1');
    return bookings;
  }

  @override
  Stream<List<Booking>> getUserBookings(String userId) =>
      const Stream<List<Booking>>.empty();
}

Booking _booking({
  required String id,
  required String stadiumName,
  required DateTime start,
  required BookingStatus status,
}) {
  return Booking(
    id: id,
    stadiumId: 'stadium-$id',
    stadiumName: stadiumName,
    ownerId: 'owner-1',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 120,
    paymentMethod: 'cash',
    status: status,
    createdByUserId: 'player-1',
    createdAt: start.subtract(const Duration(days: 1)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows player bookings in deterministic order and scrolls history',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final repository = _BookingRepository([
      _booking(
        id: 'later',
        stadiumName: 'Later Stadium',
        start: now.add(const Duration(days: 2)),
        status: BookingStatus.confirmed,
      ),
      _booking(
        id: 'history',
        stadiumName: 'History Stadium',
        start: now.subtract(const Duration(days: 2)),
        status: BookingStatus.completed,
      ),
      _booking(
        id: 'sooner',
        stadiumName: 'Soon Stadium',
        start: now.add(const Duration(days: 1)),
        status: BookingStatus.confirmed,
      ),
    ]);
    final bookingProvider = BookingProvider(repository: repository);
    addTearDown(bookingProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _AuthProvider()),
          ChangeNotifierProvider<BookingProvider>.value(value: bookingProvider),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BookingsScreen(
            loadTeamIds: (_) async => <String>{},
            loadCaptainTeamIds: (_) async => <String>{},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Soon Stadium'), findsOneWidget);
    expect(find.text('Later Stadium'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Soon Stadium')).dy,
      lessThan(tester.getTopLeft(find.text('Later Stadium')).dy),
    );

    await tester.scrollUntilVisible(
      find.text('History Stadium'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('History Stadium'), findsOneWidget);
  });
}
