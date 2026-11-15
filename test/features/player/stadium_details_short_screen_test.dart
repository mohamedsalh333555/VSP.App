import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/screens/stadium_details_screen.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart';
import 'package:vsp_application/features/player/widgets/stadium_details/stadium_image_carousel.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _GuestAuth extends Fake implements AuthProvider {
  @override
  UserModel? get userModel => null;
}

void main() {
  testWidgets('short Arabic screen scrolls notices and gallery above fixed price bar',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final stadium = Stadium(
      id: 'short-screen-pitch',
      name: 'ملعب النيل',
      location: 'أسوان',
      imageUrl: '',
      type: 'Football',
      size: '5 vs 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 200,
      area: 'أسوان',
      isVerified: true,
      maintenanceUntil: DateTime.now().add(const Duration(days: 2)),
    );
    await tester.pumpWidget(Provider<AuthProvider>.value(
      value: _GuestAuth(),
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: StadiumDetailsScreen(
          stadium: stadium,
          stadiumSnapshots: Stream<List<Map<String, dynamic>>>.error(
            StateError('offline'),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('الملعب مغلق للصيانة مؤقتًا'), findsOneWidget);
    expect(find.textContaining('تعذر تحديث بيانات الملعب'), findsOneWidget);
    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.textContaining('الملعب مغلق للصيانة مؤقتًا')).top,
      greaterThanOrEqualTo(24),
    );

    final bar = find.byType(StadiumBottomBookingBar);
    final barBefore = tester.getRect(bar);
    final imageBefore = tester.getRect(find.byType(StadiumImageCarousel));
    expect(barBefore.bottom, lessThanOrEqualTo(568));
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(bar), barBefore);
    expect(tester.getRect(find.byType(StadiumImageCarousel)).top,
        lessThan(imageBefore.top));
    expect(VSPColors.accent, const Color(0xFFA1A1AA));
  });
}
