import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/tokens/vsp_design_tokens.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/core/utils/vsp_financial_formatter.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:vsp_application/shared/widgets/vsp_payment_summary_card.dart';

void main() {
  group('VSP Design System Token Aliasing', () {
    test('Legacy VSPColors aliases VSPDSSemanticColors', () {
      expect(VSPColors.background, VSPDSSemanticColors.background);
      expect(VSPColors.surface, VSPDSSemanticColors.surface);
      expect(VSPColors.accent, VSPDSSemanticColors.accent);
      expect(VSPColors.info, VSPDSSemanticColors.info);
      expect(VSPColors.textPrimary, VSPDSSemanticColors.textPrimary);
      expect(VSPColors.textSecondary, VSPDSSemanticColors.textSecondary);
      expect(VSPColors.error, VSPDSSemanticColors.error);
      expect(VSPColors.warning, VSPDSSemanticColors.warning);
      expect(VSPColors.success, VSPDSSemanticColors.success);
    });

    test('Legacy VSPSpacing & VSPRadius match VSPDSSpacing & VSPDSRadius', () {
      expect(VSPSpacing.xs, VSPDSSpacing.xxs);
      expect(VSPSpacing.sm, VSPDSSpacing.xs);
      expect(VSPSpacing.md, VSPDSSpacing.sm);
      expect(VSPSpacing.lg, VSPDSSpacing.md);
      expect(VSPRadius.sm, VSPDSRadius.sm);
      expect(VSPRadius.md, VSPDSRadius.md);
      expect(VSPRadius.lg, VSPDSRadius.lg);
    });
  });

  group('VSPFinancialFormatter', () {
    test('formats amounts consistently with currency', () {
      expect(
        VSPFinancialFormatter.formatCurrency(100, isArabic: false, decimals: 2),
        '100.00 EGP',
      );
      expect(
        VSPFinancialFormatter.formatCurrency(105.5, isArabic: true),
        '105.50 ج.م',
      );
    });
  });

  group('VSPPaymentSummaryCard', () {
    testWidgets('renders exact 100 EGP breakdown without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VSPPaymentSummaryCard(
                baseAmount: 100.0,
                playerVspFee: 5.0,
                gatewayFee: 5.52,
                totalAmount: 110.52,
                paymentStatus: 'Paid',
                isArabic: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('100 EGP'), findsOneWidget);
      expect(find.text('5 EGP'), findsOneWidget);
      expect(find.text('5.52 EGP'), findsOneWidget);
      expect(find.text('110.52 EGP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'matches golden snapshot for canonical 100 EGP breakdown',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 420));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: VSPDSSemanticColors.background,
              body: Padding(
                padding: EdgeInsets.all(16),
                child: VSPPaymentSummaryCard(
                  baseAmount: 100.0,
                  playerVspFee: 5.0,
                  gatewayFee: 5.52,
                  totalAmount: 110.52,
                  paymentStatus: 'Paid',
                  isArabic: false,
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(VSPPaymentSummaryCard),
          matchesGoldenFile('goldens/vsp_payment_summary_card.png'),
        );
      },
    );
  });

  group('Responsive, RTL/LTR & Accessibility Verification', () {
    for (final width in [320.0, 390.0, 800.0]) {
      for (final isArabic in [true, false]) {
        testWidgets(
          'VSPPaymentSummaryCard & PrimaryButton render cleanly at ${width.toInt()}px (${isArabic ? "RTL" : "LTR"}) with 1.5x text scale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await tester.pumpWidget(
              MaterialApp(
                home: Directionality(
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.5),
                    ),
                    child: Scaffold(
                      body: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          VSPPaymentSummaryCard(
                            baseAmount: 100.0,
                            playerVspFee: 5.0,
                            gatewayFee: 5.52,
                            totalAmount: 110.52,
                            paymentStatus: isArabic ? 'مدفوع' : 'Paid',
                            isArabic: isArabic,
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            text: isArabic ? 'ادفع الآن' : 'Pay Now',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('PrimaryButton meets >= 48dp touch target and exposes label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PrimaryButton(
                text: 'Confirm Booking',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final buttonSize = tester.getSize(find.byType(PrimaryButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
      expect(find.text('Confirm Booking'), findsOneWidget);
    });
  });
}
