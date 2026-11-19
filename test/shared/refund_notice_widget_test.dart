import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/refund_info.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/widgets/refund_notice_widget.dart';

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets(
      'refund disclosure distinguishes unknown, zero and recorded amounts in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        Future<void> show(RefundInfo info) => tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RefundNoticeWidget(
                  refundInfo: info,
                  amountFormatted: '50 EGP',
                ),
              ),
            ),
          ),
        );

        final timeline = language == 'ar'
            ? 'المدة المتوقعة'
            : 'Expected timeline';
        final noRefund = language == 'ar'
            ? 'لا يوجد مبلغ مسترد مستحق وفق بيانات الدفع المسجلة لهذا الحجز.'
            : 'No refund is due according to the recorded payment details.';
        final unknown = language == 'ar'
            ? 'سيتم تأكيد مبلغ الاسترداد من الخادم بعد إلغاء الحجز.'
            : 'The server will confirm the refundable amount after cancellation.';
        Finder timelineText() => find.textContaining(timeline);

        // An unpaid cash booking has no transfer to time, even if its channel
        // defaults to the legacy "immediate" estimate.
        await show(
          RefundInfo.fromBookingRow({
            'payment_method': 'cash',
            'payment_status': 'unpaid',
          }),
        );
        expect(find.text(noRefund), findsOneWidget);
        expect(timelineText(), findsNothing);
        expect(tester.takeException(), isNull);

        // A paid booking without a server refund amount cannot promise an ETA.
        await show(
          RefundInfo.fromBookingRow({
            'payment_method': 'card',
            'payment_status': 'paid',
            'is_paid': true,
          }),
        );
        expect(find.text(unknown), findsOneWidget);
        expect(timelineText(), findsNothing);
        expect(tester.takeException(), isNull);

        await show(
          RefundInfo.fromBookingRow({
            'payment_method': 'card',
            'payment_status': 'paid',
            'refund_amount': 0,
          }),
        );
        expect(find.text(noRefund), findsOneWidget);
        expect(timelineText(), findsNothing);
        expect(tester.takeException(), isNull);

        // A recorded positive refund retains its estimated timeline and wraps
        // instead of overflowing at accessibility text sizes.
        await show(
          RefundInfo.fromBookingRow({
            'payment_method': 'card',
            'payment_status': 'refunded',
            'refund_amount': 50,
            'refund_eta': '3-5_business_days',
          }),
        );
        expect(find.textContaining('50 EGP'), findsOneWidget);
        expect(timelineText(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
