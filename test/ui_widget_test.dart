import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';
import 'package:vsp_application/shared/widgets/vsp_empty_state.dart';
import 'package:vsp_application/shared/widgets/vsp_terms_checkbox.dart';
import 'package:vsp_application/shared/dialogs/vsp_terms_and_privacy_modal.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
 group(' VSP App UI & Widget Tests', () {
 testWidgets('1. PrimaryButton renders text and triggers onPressed tap', (WidgetTester tester) async {
 bool tapped = false;
 await tester.pumpWidget(
 MaterialApp(
 home: Scaffold(
 body: PrimaryButton(
 text: 'Confirm Selection',
 onPressed: () => tapped = true,
 ),
 ),
 ),
 );

 expect(find.text('Confirm Selection'), findsOneWidget);
 await tester.tap(find.byType(PrimaryButton));
 await tester.pumpAndSettle();
 expect(tapped, isTrue);
 });

 testWidgets('2. PrimaryButton shows CircularProgressIndicator when isLoading=true', (WidgetTester tester) async {
 await tester.pumpWidget(
 MaterialApp(
 home: Scaffold(
 body: PrimaryButton(
 text: 'Submit',
 isLoading: true,
 onPressed: () {},
 ),
 ),
 ),
 );

 expect(find.byType(CircularProgressIndicator), findsOneWidget);
 expect(find.text('Submit'), findsNothing);
 });

 testWidgets('3. VSPAnimatedButton renders label correctly', (WidgetTester tester) async {
 await tester.pumpWidget(
 MaterialApp(
 home: Scaffold(
 body: VSPAnimatedButton(
 text: 'Book Pitch',
 onPressed: () {},
 ),
 ),
 ),
 );

 expect(find.text('Book Pitch'), findsOneWidget);
 });

 testWidgets('4. VSPEmptyState renders title and subtitle correctly', (WidgetTester tester) async {
 await tester.pumpWidget(
 const MaterialApp(
 home: Scaffold(
 body: VSPEmptyState(
 icon: Iconsax.calendar_1_copy,
 title: 'No Active Bookings',
 subtitle: 'Explore available pitches to book your match.',
 ),
 ),
 ),
 );

 expect(find.text('No Active Bookings'), findsOneWidget);
 expect(find.text('Explore available pitches to book your match.'), findsOneWidget);
 });

 testWidgets('5. PrimaryButton disabled state when onPressed is null', (WidgetTester tester) async {
 await tester.pumpWidget(
 const MaterialApp(
 home: Scaffold(
 body: PrimaryButton(
 text: 'Disabled Button',
 onPressed: null,
 ),
 ),
 ),
 );

 expect(find.text('Disabled Button'), findsOneWidget);
 });

    testWidgets('6. VSPTermsCheckbox toggles and renders correctly', (WidgetTester tester) async {
      bool val = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => VSPTermsCheckbox(
                value: val,
                onChanged: (newVal) => setState(() => val = newVal),
              ),
            ),
          ),
        ),
      );

      expect(val, isFalse);
      await tester.tap(find.byType(AnimatedContainer));
      await tester.pumpAndSettle();
      expect(val, isTrue);
    });

    for (final locale in [const Locale('ar'), const Locale('en')]) {
      testWidgets('7. Player terms show the current cancellation policy and dismiss in ${locale.languageCode}', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => VSPTermsAndPrivacyModal.show(ctx, isOwner: false),
                  child: const Text('Open Terms'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Terms'));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        final isArabic = locale.languageCode == 'ar';
        final cutoff = isArabic ? '6 ساعات أو أقل' : '6 hours or less';
        final grace = isArabic ? 'أول 20 دقيقة' : 'first 20 minutes';
        final policy = find.textContaining(cutoff);
        expect(policy, findsOneWidget);
        final policyText = tester.widget<Text>(policy).data!;
        expect(policyText, contains(grace));
        expect(policyText, isNot(contains('100%')));
        expect(policyText, contains(isArabic
            ? 'حالة الحجز والمدفوعات المسجلة'
            : 'booking state and recorded payments'));
        expect(Directionality.of(tester.element(policy)),
            isArabic ? TextDirection.rtl : TextDirection.ltr);

        await tester.tap(find.text(isArabic ? 'موافق' : 'I Understand'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
