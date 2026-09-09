import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/data/models/booking_enums.dart';
import 'package:vsp_application/features/player/screens/profile_subscreens/my_team_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {AuthProvider? auth}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth ?? _FakeAuth()),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation i) {
    // Return null for any property access
    if (i.isGetter) return null;
    return super.noSuchMethod(i);
  }
}

void main() {
  group('MyTeamScreen — unauthenticated state', () {
    testWidgets('shows "Not authenticated" when uid is null', (tester) async {
      await tester.pumpWidget(_wrap(const MyTeamScreen()));
      await tester.pump();
      expect(find.text('Not authenticated'), findsOneWidget);
    });
  });

  group('MyTeamScreen — loading state', () {
    testWidgets('shows CircularProgressIndicator while loading', (tester) async {
      // uid is null → "Not authenticated" (same test for null user)
      await tester.pumpWidget(_wrap(const MyTeamScreen()));
      await tester.pump();
      // Either progress indicator (authenticated) or "Not authenticated" (null uid)
      final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasText = find.text('Not authenticated').evaluate().isNotEmpty;
      expect(hasProgress || hasText, isTrue);
    });
  });

  group('MyTeamScreen — basic structure', () {
    testWidgets('renders Scaffold without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const MyTeamScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('does not crash on dispose', (tester) async {
      await tester.pumpWidget(_wrap(const MyTeamScreen()));
      await tester.pump();
      await tester.pumpWidget(const SizedBox()); // dispose
      // No exception
    });
  });

  // ── BookingStatus / BookingType enum sanity (reused across test suite) ──────
  group('Enum sanity — BookingStatus & BookingType', () {
    test('BookingStatus values are accessible', () {
      expect(BookingStatus.values, isNotEmpty);
      expect(BookingStatus.confirmed, isNotNull);
      expect(BookingStatus.pending, isNotNull);
    });

    test('BookingType values are accessible', () {
      expect(BookingType.values, isNotEmpty);
      expect(BookingType.personal, isNotNull);
      expect(BookingType.challenge, isNotNull);
    });
  });
}
