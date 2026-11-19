import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/signup_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/vsp_terms_checkbox.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:vsp_application/shared/widgets/vsp_position_selector.dart';
import 'package:vsp_application/features/auth/widgets/signup/signup_date_of_birth_field.dart';
import 'package:vsp_application/shared/widgets/date_picker/vsp_date_picker_step_views.dart';

class FakeRegisterAuth extends ChangeNotifier implements AuthProvider {
  String? lastEmail;
  String? selectedGovernorate = 'Cairo';
  String? registrationEmail;
  String? registrationRole;
  Map<String, dynamic>? registrationMetadata;
  int registrationCalls = 0;
  bool throwOnSignup = false;
  Completer<bool>? deferredSignup;

  @override
  String get governorate => selectedGovernorate ?? '';

  @override
  String? get errorMessage => 'Provider private trace: contact@example.com';

  @override
  void setEmail(String email) => lastEmail = email;

  @override
  void setGovernorate(String value) {
    selectedGovernorate = value;
    notifyListeners();
  }

  @override
  Future<bool> updateUserLocation({bool force = false}) async => false;

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String role,
    Map<String, dynamic>? userData,
  }) async {
    registrationCalls++;
    registrationEmail = email;
    registrationRole = role;
    registrationMetadata = userData;
    if (throwOnSignup) {
      throw StateError('Database secret user exists / contact@example.com');
    }
    if (deferredSignup != null) return deferredSignup!.future;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget host(FakeRegisterAuth fake, {required String language, required bool owner}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: fake,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SignupScreen(isOwner: owner),
      ),
    );

Future<void> fillRequiredDetails(WidgetTester tester, String language, {
  bool choosePosition = false,
}) async {
  await tester.tap(find.descendant(
    of: find.byType(SignupDateOfBirthField),
    matching: find.byType(InkWell),
  ).first);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(VspDatePickerYearStep), matching: find.text('2008'),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(VspDatePickerMonthStep),
    matching: find.text(language == 'ar' ? 'يناير' : 'January'),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(VspDatePickerDayStep), matching: find.text('01'),
  ).first);
  await tester.pumpAndSettle();
  // Selecting the day commits the date and dismisses the picker itself.
  expect(find.text('2008-01-01'), findsOneWidget);

  // Name, phone, email and both passwords are the six text form fields.
  const values = [
    'Ahmed', 'Salah', '01012345678',
    ' captain@example.com ', 'StrongPassword123!', 'StrongPassword123!',
  ];
  expect(find.byType(TextFormField), findsNWidgets(values.length));
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    await tester.pump();
  }
  if (choosePosition) {
    final option = find.text(language == 'ar' ? 'مهاجم' : 'Forward');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
  }
  final terms = find.descendant(
    of: find.byType(VSPTermsCheckbox), matching: find.byType(InkWell),
  ).first;
  await tester.ensureVisible(terms);
  await tester.tap(terms);
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  final btn = find.byType(PrimaryButton).last;
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pump();
}

void main() {
  for (final language in ['ar', 'en']) {
    for (final owner in [false, true]) {
      testWidgets('${owner ? 'owner' : 'player'} registration keeps fields and allows retry after interrupted request in $language',
          (tester) async {
        final fake = FakeRegisterAuth()..deferredSignup = Completer<bool>();
        await tester.pumpWidget(host(fake, language: language, owner: owner));
        await tester.pump();
        await fillRequiredDetails(tester, language, choosePosition: !owner);
        await submit(tester);
        expect(fake.registrationCalls, 1);
        expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).isLoading, isTrue);
        expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).onPressed, isNull);

        fake.deferredSignup!.completeError(
          StateError('PRIVATE_NETWORK_INTERRUPTED'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).isLoading, isFalse);
        expect(find.textContaining('PRIVATE_NETWORK_INTERRUPTED'), findsNothing);
        final fields = find.byType(TextFormField);
        expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, 'Ahmed');
        expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, 'Salah');
        expect(tester.widget<TextFormField>(fields.at(3)).controller!.text,
            ' captain@example.com ');
        expect(find.text('2008-01-01'), findsOneWidget);
        if (!owner) {
          expect(tester.widget<VSPPositionSelector>(
              find.byType(VSPPositionSelector)).selectedPosition, 'FW');
        }
        fake.deferredSignup = null;
        await submit(tester);
        expect(fake.registrationCalls, 2);
        expect(fake.registrationMetadata?['name'], 'Ahmed Salah');
        expect(fake.registrationRole, owner ? 'owner' : 'player');
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('${owner ? 'owner' : 'player'} registration submits validated payload in $language',
          (tester) async {
        final fake = FakeRegisterAuth();
        await tester.pumpWidget(host(fake, language: language, owner: owner));
        await tester.pump();
        await fillRequiredDetails(tester, language, choosePosition: !owner);
        await submit(tester);
        expect(fake.registrationCalls, 1);
        expect(fake.registrationEmail, 'captain@example.com');
        expect(fake.lastEmail, 'captain@example.com');
        expect(fake.registrationRole, owner ? 'owner' : 'player');
        expect(fake.registrationMetadata?['name'], 'Ahmed Salah');
        expect(fake.registrationMetadata?['phone'], '01012345678');
        expect(fake.registrationMetadata?['date_of_birth'], isNotNull);
        expect(fake.registrationMetadata?['position'],
            owner ? isNull : equals('FW'));
        expect(find.textContaining('Provider private trace'), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }


    testWidgets('player cannot submit without a chosen playing position in $language',
        (tester) async {
      final fake = FakeRegisterAuth();
      await tester.pumpWidget(host(fake, language: language, owner: false));
      await tester.pump();
      await fillRequiredDetails(tester, language);
      await submit(tester);
      expect(fake.registrationCalls, 0);
      // Dismiss the validation toast; changing the option uses the real
      // selector callback, avoiding a viewport-dependent offscreen tap.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      tester.widget<VSPPositionSelector>(find.byType(VSPPositionSelector))
          .onPositionSelected('FW');
      await tester.pump();
      expect(tester.widget<VSPPositionSelector>(
          find.byType(VSPPositionSelector)).selectedPosition, 'FW');
      await submit(tester);
      expect(fake.registrationCalls, 1);
      expect(fake.registrationMetadata?['position'], 'FW');
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('registration can recover from provider exception in $language',
        (tester) async {
      final fake = FakeRegisterAuth()..throwOnSignup = true;
      await tester.pumpWidget(host(fake, language: language, owner: true));
      await tester.pump();
      await fillRequiredDetails(tester, language);
      await submit(tester);
      expect(fake.registrationCalls, 1);
      expect(find.textContaining('Database secret'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
