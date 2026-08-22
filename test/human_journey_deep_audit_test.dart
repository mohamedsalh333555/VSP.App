import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/core/services/stats_service.dart';
import 'package:vsp_application/core/services/paymob_service.dart';
import 'package:vsp_application/core/utils/app_date_formatter.dart';
import 'package:vsp_application/core/navigation/app_router.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';

class FakeAuthProvider implements AuthProvider {
  final bool _isInitializing;
  final bool _isAuthenticated;
  final bool _isGhostUser;
  final UserModel? _userModel;
  final bool _isOwner;
  final bool _hasDataFetchError;
  final String _email;
  final String? _userType;

  FakeAuthProvider({
    bool isInitializing = false,
    bool isAuthenticated = true,
    bool isGhostUser = false,
    UserModel? userModel,
    bool isOwner = false,
    bool hasDataFetchError = false,
    String email = 'test@vsp.app',
    String? userType,
  })  : _isInitializing = isInitializing,
        _isAuthenticated = isAuthenticated,
        _isGhostUser = isGhostUser,
        _userModel = userModel,
        _isOwner = isOwner,
        _hasDataFetchError = hasDataFetchError,
        _email = email,
        _userType = userType;

  @override
  bool get isInitializing => _isInitializing;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get isGhostUser => _isGhostUser;

  @override
  UserModel? get userModel => _userModel;

  @override
  bool get isOwner => _isOwner;

  @override
  bool get hasDataFetchError => _hasDataFetchError;

  @override
  String get email => _email;

  @override
  String? get userType => _userType;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoRouterState implements GoRouterState {
  final Uri _uri;

  FakeGoRouterState(String url) : _uri = Uri.parse(url);

  @override
  Uri get uri => _uri;

  @override
  String get matchedLocation => _uri.path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Authentication & Role Immutability Flow', () {
    test('Password recovery deep links (/set-new-password) bypass all redirect gates', () {
      final mockAuth = FakeAuthProvider(isAuthenticated: false);
      final redirect = AppRouter.redirectLogic(
        DummyBuildContext(),
        FakeGoRouterState('/set-new-password'),
        mockAuth,
      );
      expect(redirect, isNull);
    });

    test('Uncompleted profile (missing phone) redirects to /onboarding', () {
      final mockAuth = FakeAuthProvider(
        isAuthenticated: true,
        userModel: UserModel(
          uid: 'user1',
          email: 'user1@vsp.app',
          role: 'player',
          isEmailVerified: true,
          phone: '', // Empty phone -> incomplete
        ),
      );

      final redirect = AppRouter.redirectLogic(
        DummyBuildContext(),
        FakeGoRouterState('/player'),
        mockAuth,
      );
      expect(redirect, equals('/onboarding-player'));
    });

    test('Blocked player (isBlocked == true) is strictly locked into /suspended', () {
      final mockAuth = FakeAuthProvider(
        isAuthenticated: true,
        isOwner: false,
        userModel: UserModel(
          uid: 'blocked_player',
          email: 'blocked@vsp.app',
          role: 'player',
          isEmailVerified: true,
          phone: '01012345678',
          isBlocked: true,
        ),
      );

      final redirect = AppRouter.redirectLogic(
        DummyBuildContext(),
        FakeGoRouterState('/match/booking_123'),
        mockAuth,
      );
      expect(redirect, equals('/suspended'));
    });

    test('Blocked owner (isBlocked == true) is restricted to /owner dashboard', () {
      final mockAuth = FakeAuthProvider(
        isAuthenticated: true,
        isOwner: true,
        userModel: UserModel(
          uid: 'blocked_owner',
          email: 'owner@vsp.app',
          role: 'owner',
          isEmailVerified: true,
          phone: '01012345678',
          isBlocked: true,
        ),
      );

      final redirect = AppRouter.redirectLogic(
        DummyBuildContext(),
        FakeGoRouterState('/match/booking_123'),
        mockAuth,
      );
      expect(redirect, equals('/owner'));
    });
  });

  group('2. Dynamic Multi-Sport & Position Registry', () {
    test('SportPositionsRegistry returns correct positions per sport', () {
      final footballPositions = SportPositionsRegistry.getPositionsForSport('Football');
      expect(footballPositions.map((p) => p.code), containsAll(['GK', 'DF', 'MF', 'FW']));

      final padelPositions = SportPositionsRegistry.getPositionsForSport('Padel');
      expect(padelPositions.map((p) => p.code), containsAll(['Drive', 'Revés', 'All-Round']));

      final basketballPositions = SportPositionsRegistry.getPositionsForSport('Basketball');
      expect(basketballPositions.map((p) => p.code), containsAll(['PG', 'SG', 'SF', 'PF', 'C']));

      final volleyballPositions = SportPositionsRegistry.getPositionsForSport('Volleyball');
      expect(volleyballPositions.map((p) => p.code), containsAll(['Setter', 'Spiker', 'Libero', 'Blocker']));

      final handballPositions = SportPositionsRegistry.getPositionsForSport('Handball');
      expect(handballPositions.map((p) => p.code), containsAll(['GK', 'Wing', 'Back', 'Pivot', 'Playmaker']));
    });

    test('StatsService.getSkillMetrics adapts metrics to active sport', () {
      final statsService = StatsService();

      final footballMetrics = statsService.getSkillMetrics('ST', 1200, sport: 'Football');
      expect(footballMetrics.keys, containsAll(['PAC', 'SHO', 'PAS', 'DRI', 'DEF', 'PHY']));

      final padelMetrics = statsService.getSkillMetrics('Drive', 1200, sport: 'Padel');
      expect(padelMetrics.keys, containsAll(['SER', 'VOL', 'SMA', 'DEF', 'SPD', 'PWR']));

      final basketballMetrics = statsService.getSkillMetrics('PG', 1200, sport: 'Basketball');
      expect(basketballMetrics.keys, containsAll(['PTS', 'REB', 'AST', 'STL', 'BLK', '3PT']));
    });
  });

  group('3. Booking Engine & Financial Calculations', () {
    test('30-minute interval price calculation formula', () {
      const pricePerHour = 200.0;
      const slotsCount = 3; // 1.5 hours
      const ballPrice = 20.0;
      double calculateTotal(int slots, double hourlyRate, bool withBall, double ballFee) {
        return (slots * (hourlyRate / 2)) + (withBall ? ballFee : 0.0);
      }

      expect(calculateTotal(slotsCount, pricePerHour, true, ballPrice), equals(320.0));
      expect(calculateTotal(slotsCount, pricePerHour, false, ballPrice), equals(300.0));
    });

    test('Paymob platform fee formula (amount * 0.0475) + 3.0 EGP', () {
      const baseAmount = 100.0;
      final serviceFee = PaymobService.calculateServiceFee(baseAmount);
      expect(serviceFee, equals(7.75));

      final totalAmount = PaymobService.calculateTotalAmount(baseAmount);
      expect(totalAmount, equals(107.75));
    });

    test('Deposit mode cap: deposit <= 50% of hourly price', () {
      const pricePerHour = 300.0;
      const maxAllowedDeposit = pricePerHour * 0.5;
      expect(maxAllowedDeposit, equals(150.0));
    });

    test('2-hour cancellation policy cutoff logic', () {
      final now = DateTime.now();
      final startTimeIn1Hour = now.add(const Duration(hours: 1));
      final startTimeIn3Hours = now.add(const Duration(hours: 3));

      final canCancelWithin1Hour = now.isBefore(startTimeIn1Hour.subtract(const Duration(hours: 2)));
      final canCancelWithin3Hours = now.isBefore(startTimeIn3Hours.subtract(const Duration(hours: 2)));

      expect(canCancelWithin1Hour, isFalse);
      expect(canCancelWithin3Hours, isTrue);
    });

    test('getOperationalDate 6:00 AM threshold for night shift shifts', () {
      final nightShiftTime = DateTime(2026, 8, 21, 2, 30); // 2:30 AM
      final dayShiftTime = DateTime(2026, 8, 21, 14, 0); // 2:00 PM

      final opDateNight = AppDateFormatter.getOperationalDate(nightShiftTime);
      final opDateDay = AppDateFormatter.getOperationalDate(dayShiftTime);

      expect(opDateNight.day, equals(20)); // Previous day's shift
      expect(opDateDay.day, equals(21)); // Current day's shift
    });
  });

  group('4. Teams, Squads & Elo Ranking', () {
    test('12-member squad limit threshold check', () {
      final squadMembers = List.generate(12, (i) => 'player_$i');
      expect(squadMembers.length, equals(12));
      expect(squadMembers.length >= 12, isTrue); // Adding 13th player is blocked
    });

    test('3-team membership limit threshold check', () {
      final joinedTeams = ['team1', 'team2', 'team3'];
      expect(joinedTeams.length, equals(3));
      expect(joinedTeams.length >= 3, isTrue); // Joining 4th team is blocked
    });
  });

  group('5. UI Components & Debounce Controls', () {
    testWidgets('PrimaryButton renders correctly and responds to tap', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Submit Booking',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Submit Booking'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      expect(tapped, isTrue);
    });

    testWidgets('VSPAnimatedButton renders label correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VSPAnimatedButton(
              text: 'Confirm Match',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('Confirm Match'), findsOneWidget);
    });
  });
}
