import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

void main() {
  Stadium sample() => Stadium(
        id: 'fixture-stadium',
        name: 'Sample pitch',
        location: 'Aswan',
        imageUrl: '',
        type: 'Football',
        size: '5 vs 5',
        baths: 0,
        cafeteria: 0,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pricePerHour: 2500,
        basePrice: 2500,
        area: 'Aswan',
        depositAmount: 300,
        needsDeposit: true,
      );

  Widget screen({required String locale, required double scale}) {
    return MaterialApp(
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        bottomNavigationBar: StadiumBottomBookingBar(
          stadium: sample(),
          bookingEnabled: false,
        ),
      ),
    );
  }

  testWidgets('narrow Arabic view shows price, deposit and disabled booking',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(screen(locale: 'ar', scale: 2));
    await tester.pumpAndSettle();
    expect(find.text('احجز الآن'), findsOneWidget);
    expect(find.textContaining('عربون:'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English wide view preserves horizontal action layout',
      (tester) async {
    tester.view.physicalSize = const Size(420, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(screen(locale: 'en', scale: 1));
    await tester.pumpAndSettle();
    expect(find.text('Book Now'), findsOneWidget);
    expect(find.textContaining('Deposit:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
