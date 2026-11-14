import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking_type_modal.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievement_badges.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievement_summary.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  Stadium sampleStadium() => Stadium(
        id: 'fixture-stadium',
        name: 'Test pitch',
        location: 'Aswan',
        imageUrl: '',
        type: 'Football',
        size: '5 vs 5',
        baths: 0,
        cafeteria: 0,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pricePerHour: 300,
        area: 'Aswan',
      );

  Widget localized({required Locale locale, required Widget child}) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2.5),
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets('booking types stay readable on narrow large-text Arabic',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      localized(
        locale: const Locale('ar'),
        child: BookingTypeModal(stadium: sampleStadium()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('حجز ملعب عادي'), findsOneWidget);
    expect(find.text('مباراة تحدي فرق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('team achievement badge semantics remain visible at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      localized(
        locale: const Locale('ar'),
        child: const Align(
          alignment: Alignment.topCenter,
          child: TeamAchievementBadges(
            summary: TeamAchievementSummary(
              stadiumChampionships: 3,
              oneVsOneChampionPlayers: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('3 بطولات ملاعب رسمية، 2 أبطال واحد ضد واحد'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
