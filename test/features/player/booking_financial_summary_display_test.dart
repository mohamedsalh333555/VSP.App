import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_bottom_bar.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_financial_summary.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _AnonymousAuth extends Fake implements AuthProvider {
  @override
  UserModel? get userModel => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

Stadium _stadium() => Stadium(
      id: 'pitch-1',
      name: 'Nile Pitch',
      location: 'Aswan',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 200,
      area: 'Aswan',
      depositAmount: 50,
      needsDeposit: true,
      ballPrice: 30,
      hasBall: true,
      isVerified: true,
    );

Widget _screen({required bool selected, required double total}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AnonymousAuth(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BookingFinancialSummary(
            stadium: _stadium(),
            totalPrice: total,
            hasSelectedSlots: selected,
          ),
          bottomNavigationBar: BookingBottomBar(
            isOpenJoin: false,
            isPrivate: true,
            onPrivateChanged: (_) {},
            initialPlayersCount: 1,
            maxPlayersCount: 10,
            onPlayersCountChanged: (_) {},
            hasBallOption: true,
            isBallRented: total == 230,
            onBallRentedChanged: (_) {},
            ballPrice: 30,
            totalPrice: total,
            depositAmount: 50,
            needsDeposit: true,
            isSlotSelected: selected,
            isLoading: false,
            onConfirmPressed: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('before a slot, remaining is deferred and deposit badge hidden',
      (tester) async {
    await tester.pumpWidget(_screen(selected: false, total: 0));
    expect(find.text('Calculated after selecting a slot'), findsOneWidget);
    expect(find.text('Dep 50'), findsNothing);
    expect(find.text('0 EGP'), findsOneWidget);
  });

  testWidgets('duration and ball add-on update total and remaining',
      (tester) async {
    await tester.pumpWidget(_screen(selected: true, total: 200));
    expect(find.text('200 EGP'), findsOneWidget);
    expect(find.text('150 EGP'), findsOneWidget);
    expect(find.text('Dep 50'), findsOneWidget);

    await tester.pumpWidget(_screen(selected: true, total: 230));
    expect(find.text('230 EGP'), findsOneWidget);
    expect(find.text('180 EGP'), findsOneWidget);

    await tester.pumpWidget(_screen(selected: true, total: 400));
    expect(find.text('400 EGP'), findsOneWidget);
    expect(find.text('350 EGP'), findsOneWidget);
  });
}
