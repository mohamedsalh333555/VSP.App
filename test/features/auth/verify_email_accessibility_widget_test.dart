import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/widgets/verify_email/otp_box.dart';

void main() {
  Future<void> verifyAccessibleDigit(
    WidgetTester tester, {
    required Locale locale,
    required int digitPosition,
    required String label,
  }) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final semantics = tester.ensureSemantics();
    String? changed;

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Center(
            child: OtpBox(
              digitPosition: digitPosition,
              controller: controller,
              focusNode: focusNode,
              hasError: false,
              onChanged: (value) => changed = value,
              onKey: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(label), findsOneWidget);
    await tester.enterText(find.byType(TextField), '7');
    await tester.pump();
    expect(changed, '7');
    expect(controller.text, '7');

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
    controller.dispose();
    focusNode.dispose();
  }

  testWidgets('English reader identifies the first OTP box', (tester) async {
    await verifyAccessibleDigit(
      tester,
      locale: const Locale('en'),
      digitPosition: 1,
      label: 'Verification code digit 1 of 6',
    );
  });

  testWidgets('English reader identifies the final OTP box', (tester) async {
    await verifyAccessibleDigit(
      tester,
      locale: const Locale('en'),
      digitPosition: 6,
      label: 'Verification code digit 6 of 6',
    );
  });

  testWidgets('Arabic reader identifies the first OTP box', (tester) async {
    await verifyAccessibleDigit(
      tester,
      locale: const Locale('ar'),
      digitPosition: 1,
      label: 'رمز التحقق، الرقم 1 من 6',
    );
  });

  testWidgets('Arabic reader identifies the final OTP box', (tester) async {
    await verifyAccessibleDigit(
      tester,
      locale: const Locale('ar'),
      digitPosition: 6,
      label: 'رمز التحقق، الرقم 6 من 6',
    );
  });
}
