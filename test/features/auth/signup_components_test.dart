import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/features/auth/widgets/signup/signup_date_of_birth_field.dart';
import 'package:vsp_application/features/auth/widgets/signup/signup_name_fields.dart';
import 'package:vsp_application/features/auth/widgets/signup/signup_password_strength_bar.dart';
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

  group('Signup Components Tests', () {
    testWidgets('SignupPasswordStrengthBar displays strength percentage and progress indicator', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SignupPasswordStrengthBar(password: 'weak'),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Weak'), findsOneWidget);

      await tester.pumpWidget(
        buildTestApp(
          const SignupPasswordStrengthBar(password: 'StrongP@ssw0rd!'),
        ),
      );

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Strong'), findsOneWidget);
    });

    testWidgets('SignupDateOfBirthField displays placeholder and handles tap when null', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestApp(
          SignupDateOfBirthField(
            dateOfBirth: null,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byIcon(Iconsax.calendar_1_copy), findsOneWidget);
      expect(find.byIcon(Iconsax.tick_circle_copy), findsNothing);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('SignupDateOfBirthField displays formatted date and tick when set', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SignupDateOfBirthField(
            dateOfBirth: DateTime(1995, 8, 24),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('1995-08-24'), findsOneWidget);
      expect(find.byIcon(Iconsax.tick_circle_copy), findsOneWidget);
    });

    testWidgets('SignupNameFields renders first and last name text fields and accepts input', (tester) async {
      final firstCtrl = TextEditingController();
      final lastCtrl = TextEditingController();

      await tester.pumpWidget(
        buildTestApp(
          SignupNameFields(
            firstNameController: firstCtrl,
            lastNameController: lastCtrl,
          ),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).first, 'John');
      await tester.enterText(find.byType(TextField).last, 'Doe');
      await tester.pump();

      expect(firstCtrl.text, 'John');
      expect(lastCtrl.text, 'Doe');

      firstCtrl.dispose();
      lastCtrl.dispose();
    });
  });
}
