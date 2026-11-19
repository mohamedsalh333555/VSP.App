import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

void main() {
  Stadium sample({double deposit = 300, bool needsDeposit = true,
      double hourlyPrice = 2500, double basePrice = 2500,
      bool verified = true, bool blocked = false,
      DateTime? maintenanceUntil}) => Stadium(
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
        pricePerHour: hourlyPrice,
        basePrice: basePrice,
        area: 'Aswan',
        depositAmount: deposit,
        needsDeposit: needsDeposit,
        isVerified: verified,
        isBlocked: blocked,
        maintenanceUntil: maintenanceUntil,
      );

  Widget screen({required String locale, required double scale,
      double deposit = 300, bool needsDeposit = true,
      double hourlyPrice = 2500, double basePrice = 2500,
      bool bookingEnabled = false, bool verified = true,
      bool blocked = false, DateTime? maintenanceUntil}) {
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
          stadium: sample(deposit: deposit, needsDeposit: needsDeposit,
              hourlyPrice: hourlyPrice, basePrice: basePrice,
              verified: verified, blocked: blocked,
              maintenanceUntil: maintenanceUntil),
          bookingEnabled: bookingEnabled,
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
  testWidgets('unknown mandatory deposit never appears as no-deposit offer', (tester) async {
    for (final deposit in [0.0, -1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(screen(
        locale: 'en', scale: 1, deposit: deposit));
      await tester.pumpAndSettle();
      expect(find.text('Deposit amount unavailable'), findsOneWidget);
      expect(find.text('No deposit required'), findsNothing);
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(screen(
      locale: 'ar', scale: 1, deposit: 0));
    await tester.pumpAndSettle();
    expect(find.text('العربون غير متاح حاليًا'), findsOneWidget);
    expect(find.text('لا يوجد عربون مطلوب'), findsNothing);
  });

  testWidgets('zero deposit is explicitly valid only when owner does not require one',
      (tester) async {
    await tester.pumpWidget(screen(
      locale: 'en', scale: 1, needsDeposit: false, deposit: 0));
    await tester.pumpAndSettle();
    expect(find.text('No deposit required'), findsOneWidget);
    expect(find.text('Deposit amount unavailable'), findsNothing);
  });


  testWidgets('invalid mandatory deposit disables Book Now even if caller enables it',
      (tester) async {
    for (final deposit in [0.0, -1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(screen(locale: 'en', scale: 1,
          deposit: deposit, needsDeposit: true, bookingEnabled: true));
      await tester.pumpAndSettle();
      expect(find.text('Deposit amount unavailable'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(
          find.byType(PrimaryButton)).onPressed, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('invalid hourly or base price disables Book Now locally',
      (tester) async {
    for (final price in [0.0, -1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(screen(locale: 'en', scale: 1,
          hourlyPrice: price, bookingEnabled: true));
      await tester.pumpAndSettle();
      expect(tester.widget<PrimaryButton>(
          find.byType(PrimaryButton)).onPressed, isNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(screen(locale: 'en', scale: 1,
          basePrice: price, bookingEnabled: true));
      await tester.pumpAndSettle();
      expect(tester.widget<PrimaryButton>(
          find.byType(PrimaryButton)).onPressed, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('valid deposit and price preserve enabled Book Now action',
      (tester) async {
    await tester.pumpWidget(screen(locale: 'ar', scale: 1,
        deposit: 300, bookingEnabled: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('عربون:'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(
        find.byType(PrimaryButton)).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });


  testWidgets('venue is not directly bookable when unverified, blocked or in maintenance',
      (tester) async {
    final maintenance = DateTime.now().add(const Duration(days: 2));
    final cases = <Map<String, dynamic>>[
      {'verified': false},
      {'blocked': true},
      {'maintenanceUntil': maintenance},
    ];
    for (final state in cases) {
      await tester.pumpWidget(screen(
        locale: 'en', scale: 1, bookingEnabled: true,
        verified: state['verified'] as bool? ?? true,
        blocked: state['blocked'] as bool? ?? false,
        maintenanceUntil: state['maintenanceUntil'] as DateTime?,
      ));
      await tester.pumpAndSettle();
      expect(tester.widget<PrimaryButton>(
          find.byType(PrimaryButton)).onPressed, isNull,
          reason: 'Booking must fail closed for $state');
      expect(tester.takeException(), isNull);
    }
  });

}
