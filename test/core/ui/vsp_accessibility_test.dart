import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/components/vsp_button.dart';
import 'package:vsp_application/core/ui/vsp_ui.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/vsp_fade_in_item.dart';

Widget harness(
  Widget child, {
  String language = 'en',
  bool reduceMotion = false,
}) {
  return MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(2),
        disableAnimations: reduceMotion,
      ),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('primary action accommodates large text in $language', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final label = language == 'ar'
          ? 'حاول تحميل البيانات مرة أخرى'
          : 'Try loading the data again';
      await tester.pumpWidget(
        harness(
          Center(
            child: VSPPrimaryButton(text: label, onPressed: () {}),
          ),
          language: language,
        ),
      );
      await tester.pump();
      final labelBounds = tester.getRect(find.text(label));
      final buttonBounds = tester.getRect(find.byType(ElevatedButton));
      expect(buttonBounds.contains(labelBounds.topLeft), isTrue);
      expect(buttonBounds.contains(labelBounds.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    });

    for (final state in VSPUiState.values) {
      testWidgets('$state remains scrollable at large text in $language', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 240));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var retries = 0;
        await tester.pumpWidget(
          harness(
            VSPStateView(
              state: state,
              title: language == 'ar'
                  ? 'حالة تحميل البيانات'
                  : 'Data loading status',
              message: language == 'ar'
                  ? 'تحقق من اتصال الإنترنت ثم حاول تحميل البيانات مرة أخرى.'
                  : 'Check the internet connection and try loading the data again.',
              onRetry: () => retries++,
            ),
            language: language,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (state == VSPUiState.error || state == VSPUiState.offline) {
          final retry = find.byType(OutlinedButton);
          await tester.ensureVisible(retry);
          await tester.tap(retry);
          await tester.pump();
          expect(retries, 1);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('reduced motion reveals staggered content immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const VSPFadeInItem(
          delay: Duration(seconds: 5),
          child: Text('Content'),
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    final fade = find.descendant(
      of: find.byType(VSPFadeInItem),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
