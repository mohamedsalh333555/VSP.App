import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/payment/paymob_callback_url_parser.dart';
import 'package:vsp_application/features/player/widgets/payment/paymob_still_waiting_dialog.dart';
import 'package:vsp_application/features/player/widgets/payment/paymob_web_fallback_view.dart';

void main() {
  group('PaymobCallbackUrlParser', () {
    test('isSafeDomain identifies valid payment gateway hosts', () {
      expect(PaymobCallbackUrlParser.isSafeDomain('https://accept.paymob.com/portal'), isTrue);
      expect(PaymobCallbackUrlParser.isSafeDomain('https://nbe.com.eg/checkout'), isTrue);
      expect(PaymobCallbackUrlParser.isSafeDomain('https://banquemisr.com/pay'), isTrue);
      expect(PaymobCallbackUrlParser.isSafeDomain('https://cibeg.com/verify'), isTrue);
      expect(PaymobCallbackUrlParser.isSafeDomain('https://malicious-site.com'), isFalse);
    });

    test('isBank3DsDomain identifies 3DS security redirect patterns', () {
      expect(PaymobCallbackUrlParser.isBank3DsDomain('https://acs.bank.com/challenge'), isTrue);
      expect(PaymobCallbackUrlParser.isBank3DsDomain('https://mpgs.gateway.com/session'), isTrue);
      expect(PaymobCallbackUrlParser.isBank3DsDomain('https://bank.com/3dsecure/auth'), isTrue);
      expect(PaymobCallbackUrlParser.isBank3DsDomain('https://accept.paymob.com/post_pay'), isFalse);
    });

    test('evaluateUrl returns pendingOrIgnored during bank 3DS checks', () {
      final status = PaymobCallbackUrlParser.evaluateUrl('https://acs.bank.com/challenge?success=true');
      expect(status, equals(PaymobCallbackStatus.pendingOrIgnored));
    });

    test('evaluateUrl returns success on explicit Paymob approval params', () {
      expect(
        PaymobCallbackUrlParser.evaluateUrl('https://accept.paymob.com/post_pay?success=true&id=123'),
        equals(PaymobCallbackStatus.success),
      );
      expect(
        PaymobCallbackUrlParser.evaluateUrl('https://checkout.paymob.com/api/vsp_payment_callback?txn_response_code=approved'),
        equals(PaymobCallbackStatus.success),
      );
      expect(
        PaymobCallbackUrlParser.evaluateUrl('https://accept.paymob.com/post_pay?txn_response_code=00'),
        equals(PaymobCallbackStatus.success),
      );
      expect(
        PaymobCallbackUrlParser.evaluateUrl('https://www.vspapp.online/payment-callback?id=540006822&pending=false&amount_cents=33820&success=true&txn_response_code=APPROVED'),
        equals(PaymobCallbackStatus.success),
      );
    });

    test('evaluateUrl returns failure on explicit rejection params', () {
      expect(
        PaymobCallbackUrlParser.evaluateUrl('https://accept.paymob.com/post_pay?success=false'),
        equals(PaymobCallbackStatus.failure),
      );
      expect(
        PaymobCallbackUrlParser.evaluateUrl('https://accept.paymob.com/post_pay?txn_response_code=declined'),
        equals(PaymobCallbackStatus.failure),
      );
    });

    test('evaluateUrl returns pendingOrIgnored for unrelated URLs', () {
      expect(
        PaymobCallbackUrlParser.evaluateUrl('https://google.com'),
        equals(PaymobCallbackStatus.pendingOrIgnored),
      );
    });
  });

  group('PaymobStillWaitingDialog', () {
    testWidgets('renders dialog options and responds to tap', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await PaymobStillWaitingDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Payment Taking Longer'), findsOneWidget);
      expect(find.text('Keep Waiting'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Keep Waiting'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('returns true when cancel is tapped', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await PaymobStillWaitingDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('PaymobWebFallbackView', () {
    testWidgets('renders fallback view and triggers callbacks', (tester) async {
      var reopened = false;
      var manuallyVerified = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymobWebFallbackView(
              onReopen: () => reopened = true,
              onManualVerify: () => manuallyVerified = true,
            ),
          ),
        ),
      );

      expect(find.text('Opening secure payment gateway...'), findsOneWidget);
      expect(find.text('Re-open Payment Window'), findsOneWidget);
      expect(find.text('Verify Payment Status'), findsOneWidget);

      await tester.tap(find.text('Re-open Payment Window'));
      await tester.pump();
      expect(reopened, isTrue);

      await tester.tap(find.text('Verify Payment Status'));
      await tester.pump();
      expect(manuallyVerified, isTrue);
    });
  });
}
