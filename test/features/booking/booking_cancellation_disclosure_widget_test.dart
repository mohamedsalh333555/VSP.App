import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_cancellation_policy_note.dart';
import 'package:vsp_application/l10n/app_localizations_ar.dart';
import 'package:vsp_application/l10n/app_localizations_en.dart';

void main() {
  test('venue policy and FAQ agree on cutoff without promising a full refund', () {
    final arabic = AppLocalizationsAr();
    final english = AppLocalizationsEn();

    expect(arabic.cancellationPolicy, contains('أكثر من 6 ساعات'));
    expect(arabic.cancellationPolicy, contains('أول 20 دقيقة'));
    expect(arabic.cancellationPolicy, contains('6 ساعات أو أقل'));
    expect(arabic.cancellationPolicy, isNot(contains('عمولة المنصة')));
    expect(arabic.faq3_a, contains('أكثر من 6 ساعات'));
    expect(arabic.faq3_a, isNot(contains('كامل المبلغ')));

    expect(english.cancellationPolicy, contains('more than 6 hours'));
    expect(english.cancellationPolicy, contains('first 20 minutes'));
    expect(english.cancellationPolicy, contains('6 hours or less'));
    expect(english.faq3_a, isNot(contains('full refund')));
  });

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    testWidgets('cancellation cutoff is visible before expanding in ${locale.languageCode}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        locale: locale,
        home: const Scaffold(body: BookingCancellationPolicyNote()),
      ));

      final summary = locale.languageCode == 'ar'
          ? 'يمكنك الإلغاء قبل موعد المباراة بأكثر من 6 ساعات، أو خلال أول 20 دقيقة من الحجز.'
          : 'Cancel more than 6 hours before kickoff, or within the first 20 minutes after booking.';
      final details = locale.languageCode == 'ar'
          ? 'بعد مرور أول 20 دقيقة، لا يُقبل الإلغاء إذا كان متبقيًا 6 ساعات أو أقل على موعد المباراة. يحدد الخادم أهلية الإلغاء ومبلغ الاسترداد حسب حالة الحجز والدفع؛ وقد يظل الاسترداد الإلكتروني قيد المعالجة.'
          : 'After the first 20 minutes, cancellation is unavailable when 6 hours or less remain before kickoff. The server determines cancellation and refund eligibility based on booking and payment status; an online refund may still be pending.';

      expect(find.text(summary), findsOneWidget);
      expect(tester.getSize(find.byType(BookingCancellationPolicyNote)).width,
          lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
      expect(find.text(details), findsNothing);

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text(details), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
