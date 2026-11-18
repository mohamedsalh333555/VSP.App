import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/repeat_booking_action.dart';

Stadium _stadium({String id = 'venue-1', double price = 250}) =>
    Stadium.fromFirestore({
      'id': id,
      'name': 'Current Pitch',
      'price_per_hour': price,
      'is_verified': true,
      'is_blocked': false,
      'is_deleted_by_owner': false,
    }, id);

Widget _screen(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('rebook re-fetches venue, blocks double tap and never charges',
      (tester) async {
    final request = Completer<Stadium?>();
    var calls = 0;
    await tester.pumpWidget(_screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () => true,
      loadLatestStadium: (id) {
        expect(id, 'venue-1');
        calls++;
        return request.future;
      },
      detailsBuilder: (venue) => Scaffold(
        body: Text('Latest venue: ${venue.name} ${venue.basePrice}'),
      ),
    )));
    expect(find.text('Book again'), findsOneWidget);
    await tester.tap(find.text('Book again'));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The pending button is disabled until authoritative data arrives.
    expect(tester.widget<OutlinedButton>(find.byWidgetPredicate((w) => w is OutlinedButton)).onPressed, isNull);
    expect(find.textContaining('Latest venue:'), findsNothing);
    request.complete(_stadium());
    await tester.pumpAndSettle();
    expect(find.text('Latest venue: Current Pitch 250.0'), findsOneWidget);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing or deleted stadium never opens an old cached venue in Arabic',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_screen(RepeatBookingAction(
      stadiumId: 'closed',
      canContinue: () => true,
      loadLatestStadium: (id) async {
        calls++;
        return null;
      },
      detailsBuilder: (_) => const Text('NOT_ALLOWED'),
    ), locale: const Locale('ar')));
    await tester.tap(find.text('احجز تاني'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر التحقق من بيانات الملعب الحالية'), findsOneWidget);
    expect(find.text('NOT_ALLOWED'), findsNothing);
    expect(calls, 1);
  });

  testWidgets('old account cannot open rebooking after account switch in-flight',
      (tester) async {
    final pending = Completer<Stadium?>();
    var allowed = true;
    await tester.pumpWidget(_screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () => allowed,
      loadLatestStadium: (_) => pending.future,
      detailsBuilder: (_) => const Text('WRONG_ACCOUNT'),
    )));
    await tester.tap(find.text('Book again'));
    await tester.pump();
    allowed = false;
    pending.complete(_stadium());
    await tester.pumpAndSettle();
    expect(find.text('WRONG_ACCOUNT'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuilding the card keeps one live venue query', (tester) async {
    final pending = Completer<Stadium?>();
    var calls = 0;
    Future<Stadium?> load(String _) {
      calls++;
      return pending.future;
    }
    Widget screen() => _screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () => true,
      loadLatestStadium: load,
      detailsBuilder: (_) => const Scaffold(body: Text('CURRENT_VENUE')),
    ));
    await tester.pumpWidget(screen());
    await tester.tap(find.text('Book again'));
    await tester.pump();
    await tester.pumpWidget(screen());
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(_stadium());
    await tester.pumpAndSettle();
    expect(find.text('CURRENT_VENUE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new callback cannot use a switched account to rebook', (tester) async {
    final pending = Completer<Stadium?>();
    var permission = true;
    Widget screen() => _screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () => permission,
      loadLatestStadium: (_) => pending.future,
      detailsBuilder: (_) => const Scaffold(body: Text('NOT_PERMITTED')),
    ));
    await tester.pumpWidget(screen());
    await tester.tap(find.text('Book again'));
    await tester.pump();
    permission = false;
    await tester.pumpWidget(screen());
    pending.complete(_stadium());
    await tester.pumpAndSettle();
    expect(find.text('NOT_PERMITTED'), findsNothing);
  });

  testWidgets('unexpected provider failure is sanitized, then can retry',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () => true,
      loadLatestStadium: (_) async {
        calls++;
        throw StateError('PRIVATE_BACKEND_DIAGNOSTIC');
      },
    )));
    await tester.tap(find.text('Book again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not verify the latest venue details'), findsOneWidget);
    expect(find.textContaining('PRIVATE_BACKEND_DIAGNOSTIC'), findsNothing);
    await tester.tap(find.text('Book again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing or invalid current rent never opens an invented free booking',
      (tester) async {
    for (final price in [0.0, -1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(_screen(RepeatBookingAction(
        key: ValueKey('price-$price'),
        stadiumId: 'venue-1',
        canContinue: () => true,
        loadLatestStadium: (_) async => _stadium(price: price),
        detailsBuilder: (_) => const Text('UNSAFE_REBOOKING'),
      )));
      await tester.tap(find.text('Book again'));
      await tester.pumpAndSettle();
      expect(find.text('UNSAFE_REBOOKING'), findsNothing);
      expect(find.textContaining('Could not verify the latest venue details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('wrong venue id from adapter is rejected', (tester) async {
    await tester.pumpWidget(_screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () => true,
      loadLatestStadium: (_) async => _stadium(id: 'other-venue'),
      detailsBuilder: (_) => const Text('NOT_ALLOWED'),
    )));
    await tester.tap(find.text('Book again'));
    await tester.pumpAndSettle();
    expect(find.text('NOT_ALLOWED'), findsNothing);
    expect(find.textContaining('Could not verify'), findsOneWidget);
  });
  testWidgets('permission provider exception fails closed before venue lookup',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () => throw StateError('PRIVATE_AUTH_ERROR'),
      loadLatestStadium: (_) async {
        calls++;
        return _stadium();
      },
      detailsBuilder: (_) => const Text('SHOULD_NOT_OPEN'),
    )));
    await tester.tap(find.text('Book again'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('SHOULD_NOT_OPEN'), findsNothing);
    expect(find.textContaining('PRIVATE_AUTH_ERROR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission exception after fresh lookup blocks old-account navigation',
      (tester) async {
    final pending = Completer<Stadium?>();
    var allowed = true;
    await tester.pumpWidget(_screen(RepeatBookingAction(
      stadiumId: 'venue-1',
      canContinue: () {
        if (!allowed) throw StateError('STALE_AUTH_PROVIDER');
        return true;
      },
      loadLatestStadium: (_) => pending.future,
      detailsBuilder: (_) => const Text('WRONG_USER'),
    )));
    await tester.tap(find.text('Book again'));
    await tester.pump();
    allowed = false;
    pending.complete(_stadium());
    await tester.pumpAndSettle();
    expect(find.text('WRONG_USER'), findsNothing);
    expect(find.textContaining('STALE_AUTH_PROVIDER'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
