import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/tokens/vsp_design_tokens.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/core/utils/vsp_financial_formatter.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/shared/widgets/vsp_payment_summary_card.dart';

void main() {
  group('Design System Token Unification', () {
    test('Legacy VSPColors, VSPRadius, VSPSize, and VSPSpacing alias V2 tokens identically', () {
      expect(VSPColors.background, equals(VSPDSSemanticColors.background));
      expect(VSPColors.surface, equals(VSPDSSemanticColors.surface));
      expect(VSPColors.surfaceAlt, equals(VSPDSSemanticColors.surfaceRaised));
      expect(VSPColors.accent, equals(VSPDSSemanticColors.accent));
      expect(VSPColors.error, equals(VSPDSSemanticColors.error));

      expect(VSPRadius.button, equals(VSPDSRadius.button));
      expect(VSPRadius.card, equals(VSPDSRadius.card));
      expect(VSPSize.buttonHeight, equals(VSPDSizes.buttonHeight));

      expect(VSPSpacing.xs, equals(VSPDSSpacing.xxs));
      expect(VSPSpacing.sm, equals(VSPDSSpacing.xs));
      expect(VSPSpacing.md, equals(VSPDSSpacing.sm));
      expect(VSPSpacing.lg, equals(VSPDSSpacing.md));
      expect(VSPSpacing.xxl, equals(VSPDSSpacing.lg));
      expect(VSPSpacing.xxxl, equals(VSPDSSpacing.xl));
    });
  });

  group('VSPFinancialFormatter & VSPPaymentSummaryCard', () {
    test('Formats currency and statuses cleanly in Arabic and English', () {
      expect(VSPFinancialFormatter.formatCurrency(100, isArabic: true), equals('100 ج.م'));
      expect(VSPFinancialFormatter.formatCurrency(110.66, isArabic: true), equals('110.66 ج.م'));
      expect(VSPFinancialFormatter.formatCurrency(110.66, isArabic: false), equals('110.66 EGP'));

      expect(
        VSPFinancialFormatter.localizeBookingStatus(BookingStatus.confirmed, isArabic: true),
        equals('مؤكد'),
      );
      expect(
        VSPFinancialFormatter.localizePaymentStatus('paid', isArabic: true),
        equals('مدفوع بالكامل'),
      );
    });

    testWidgets('VSPPaymentSummaryCard renders exact 100 EGP breakdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VSPPaymentSummaryCard(
              baseAmount: 100,
              playerVspFee: 5,
              gatewayFee: 5.66,
              totalAmount: 110.66,
              paymentStatus: 'paid',
              isArabic: true,
            ),
          ),
        ),
      );

      expect(find.text('100 ج.م'), findsOneWidget);
      expect(find.text('5 ج.م'), findsOneWidget);
      expect(find.text('5.66 ج.م'), findsOneWidget);
      expect(find.text('110.66 ج.م'), findsOneWidget);
      expect(find.text('مدفوع بالكامل'), findsOneWidget);
    });
  });
}
