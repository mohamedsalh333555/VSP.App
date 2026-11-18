import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/widgets/signup/signup_name_fields.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Widget host(TextEditingController first, TextEditingController last,
    {String lang = 'en'}) => MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SignupNameFields(
            firstNameController: first,
            lastNameController: last,
          ),
        ),
      ),
    );

void main() {
  for (final config in [
    (width: 320.0, scale: 1.8, language: 'ar', stacked: true),
    (width: 360.0, scale: 1.5, language: 'en', stacked: true),
    (width: 600.0, scale: 1.0, language: 'en', stacked: false),
  ]) {
    testWidgets('name inputs remain editable and accessible at ${config.width}dp',
        (tester) async {
      tester.view.physicalSize = Size(config.width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = config.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final first = TextEditingController();
      final last = TextEditingController();
      await tester.pumpWidget(host(first, last, lang: config.language));
      expect(find.byType(TextFormField), findsNWidgets(2));
      final a = tester.getTopLeft(find.byType(TextFormField).first);
      final b = tester.getTopLeft(find.byType(TextFormField).last);
      if (config.stacked) {
        expect(b.dy, greaterThan(a.dy));
      } else {
        expect((a.dy - b.dy).abs(), lessThan(5));
      }
      await tester.enterText(find.byType(TextFormField).first, 'Ahmed');
      await tester.enterText(find.byType(TextFormField).last, 'Salah');
      await tester.pump();
      expect(first.text, 'Ahmed');
      expect(last.text, 'Salah');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      last.dispose();
    });
  }
}
