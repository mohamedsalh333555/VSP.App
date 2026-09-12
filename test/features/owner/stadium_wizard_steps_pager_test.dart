import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_controllers.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_features_state.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_steps_pager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  testWidgets('StadiumWizardStepsPager mounts without error', (tester) async {
    final pageController = PageController();
    final controllers = StadiumWizardControllers();
    final featuresState = StadiumWizardFeaturesState();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        locale: const Locale('en'),
        home: Scaffold(
          body: StadiumWizardStepsPager(
            pageController: pageController,
            controllers: controllers,
            featuresState: featuresState,
            stadiumId: null,
            uid: 'test_uid',
            startTime: const TimeOfDay(hour: 10, minute: 0),
            endTime: const TimeOfDay(hour: 22, minute: 0),
            isSplitShift: false,
            breakTimes: const [],
            isSplitShiftValid: true,
            isLocationLoading: false,
            images: const [],
            isUploading: false,
            isSaving: false,
            onSelectSport: (_) {},
            onSelectTime: (_) {},
            onToggleSplitShift: (_) {},
            onSelectBreakTime: (_, __) {},
            onAddBreak: () {},
            onRemoveBreak: (_) {},
            onOpenMapPicker: () {},
            onOpenManualPicker: () {},
            onAddNoteTemplate: (_) {},
            onNextPage: () {},
            onStateChanged: () {},
          ),
        ),
      ),
    );

    expect(find.byType(StadiumWizardStepsPager), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}
