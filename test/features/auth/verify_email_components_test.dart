import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/widgets/verify_email/otp_box.dart';
import 'package:vsp_application/features/auth/widgets/verify_email/otp_resend_section.dart';
import 'package:vsp_application/features/auth/widgets/verify_email/verify_email_header.dart';

void main() {
  group('VerifyEmail Components Tests', () {
    test('VerifyEmailHeader.maskEmail correctly masks emails', () {
      expect(VerifyEmailHeader.maskEmail('mohamed@example.com'), 'm*****d@example.com');
      expect(VerifyEmailHeader.maskEmail('ab@test.com'), '**@test.com');
      expect(VerifyEmailHeader.maskEmail('invalid-email'), 'invalid-email');
    });

    testWidgets('VerifyEmailHeader renders title and masked email', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifyEmailHeader(
              email: 'player@vsp.app',
              isAr: false,
            ),
          ),
        ),
      );

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('p****r@vsp.app'), findsOneWidget);
    });

    testWidgets('OtpBox renders and accepts digit input', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      String changed = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpBox(
              controller: controller,
              focusNode: focusNode,
              hasError: false,
              onChanged: (val) => changed = val,
              onKey: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '7');
      await tester.pump();

      expect(changed, '7');
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('OtpResendSection renders countdown and handles resend', (tester) async {
      bool resendTapped = false;
      bool changeEmailTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpResendSection(
              countdown: 0,
              isResending: false,
              isAr: false,
              onResend: () => resendTapped = true,
              onChangeEmail: () => changeEmailTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Resend Code'), findsOneWidget);
      await tester.tap(find.text('Resend Code'));
      await tester.pump();
      expect(resendTapped, isTrue);

      await tester.tap(find.text('Wrong email? Change email and sign out'));
      await tester.pump();
      expect(changeEmailTapped, isTrue);
    });

    testWidgets('OtpResendSection displays countdown when > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpResendSection(
              countdown: 42,
              isResending: false,
              isAr: false,
              onResend: () {},
              onChangeEmail: () {},
            ),
          ),
        ),
      );

      expect(find.text('Resend in 42s'), findsOneWidget);
    });
  });
}
