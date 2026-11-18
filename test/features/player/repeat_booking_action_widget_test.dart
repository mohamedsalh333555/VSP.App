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
      'base_price': price,
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
}
