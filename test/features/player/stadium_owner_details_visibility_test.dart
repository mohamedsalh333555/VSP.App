import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_payload_builder.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_information_tab.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('player details show owner location, services and booking price',
      (tester) async {
    final features = StadiumWizardPayloadBuilder.buildFeatures(
      stadiumPhone: '01000000000',
      sportType: 'Football',
      floorType: 'Artificial',
      bathOption: 'Yes',
      cafeteria: true,
      garage: false,
      changingRoom: true,
      seats: '20',
      length: '40',
      width: '20',
      hasBall: true,
      ballPrice: 15,
      startTime: null,
      endTime: null,
      isSplitShift: false,
      breakTimes: const [],
      uploadedUrls: const [],
    );
    final stadium = Stadium(
      id: 'aswan-pitch',
      name: 'Nile Pitch',
      location: 'Aswan city center',
      governorate: 'Aswan',
      lat: 24.0889,
      lng: 32.8998,
      imageUrl: '',
      type: 'Football',
      size: '5 vs 5',
      baths: 1,
      cafeteria: 1,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 300,
      area: 'Aswan city center',
      features: features,
      hasBall: true,
      ballPrice: 15,
      depositAmount: 50,
      needsDeposit: true,
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StadiumInformationTab(stadium: stadium),
        bottomNavigationBar: StadiumBottomBookingBar(
          stadium: stadium, bookingEnabled: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nile Pitch'), findsOneWidget);
    expect(find.text('أسوان المدينة'), findsOneWidget);
    expect(find.text('Cafeteria'), findsOneWidget);
    expect(find.text('Changing Rooms'), findsOneWidget);
    expect(find.text('Seats: 20'), findsOneWidget);
    expect(find.text('Parking'), findsNothing);
    expect(find.text('Match Ball Rental'), findsOneWidget);
    expect(find.textContaining('Deposit: 50 EGP'), findsOneWidget);
    expect(tester.widgetList<Text>(find.byType(Text)).any(
      (value) => value.textSpan?.toPlainText().contains('300 EGP') == true,
    ), isTrue);
    expect(tester.takeException(), isNull);
  });
}
