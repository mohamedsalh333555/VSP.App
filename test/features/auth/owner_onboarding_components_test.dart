import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/widgets/owner_onboarding/owner_onboarding_exit_dialog.dart';
import 'package:vsp_application/features/auth/widgets/owner_onboarding/owner_onboarding_location_section.dart';
import 'package:vsp_application/features/auth/widgets/owner_onboarding/owner_payout_info_card.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('Owner Onboarding Components Widget Tests', () {
    testWidgets('OwnerPayoutInfoCard renders fields and title', (tester) async {
      final instapayCtrl = TextEditingController();
      final vodafoneCtrl = TextEditingController();
      final bankCtrl = TextEditingController();

      await tester.pumpWidget(
        buildTestApp(
          OwnerPayoutInfoCard(
            instapayController: instapayCtrl,
            vodafoneController: vodafoneCtrl,
            bankController: bankCtrl,
            onSubmitted: () {},
          ),
        ),
      );

      expect(find.byType(OwnerPayoutInfoCard), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('OwnerOnboardingLocationSection renders dropdown and handles selection', (tester) async {
      String? selected;
      bool autoDetectTapped = false;

      await tester.pumpWidget(
        buildTestApp(
          OwnerOnboardingLocationSection(
            selectedGovernorate: 'Cairo',
            isFetchingLocation: false,
            isLocationFallbackActive: false,
            onGovernorateChanged: (v) => selected = v,
            onAutoDetectTapped: () => autoDetectTapped = true,
          ),
        ),
      );

      expect(find.byType(OwnerOnboardingLocationSection), findsOneWidget);
      expect(find.text('Cairo'), findsOneWidget);
    });

    testWidgets('OwnerOnboardingExitDialog opens and shows options', (tester) async {
      bool? result;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await OwnerOnboardingExitDialog.show(context);
              },
              child: const Text('Open Exit Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Exit Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Continue Registration'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
