import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/tokens/vsp_design_tokens.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/core/ui/vsp_ui.dart';
import 'package:vsp_application/core/utils/vsp_financial_formatter.dart';
import 'package:vsp_application/features/dev/design_system_showcase_screen.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:vsp_application/shared/widgets/vsp_payment_summary_card.dart';

import '../helpers/golden_test_helper.dart';

double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() async {
    await loadVspTestFonts();
  });

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

  group('VSPPaymentSummaryCard & Component Goldens', () {
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
      'matches golden snapshot for canonical 100 EGP breakdown (LTR)',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 420);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Poppins',
              fontFamilyFallback: const ['Tajawal', 'sans-serif'],
            ),
            home: const Scaffold(
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

    testWidgets(
      'matches golden snapshot for PrimaryButton & VSPStateView',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 540);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Poppins',
              fontFamilyFallback: const ['Tajawal', 'sans-serif'],
            ),
            home: Scaffold(
              backgroundColor: VSPDSSemanticColors.background,
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      text: 'Pay 110.52 EGP',
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    const PrimaryButton(
                      text: 'Disabled Action',
                      onPressed: null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: VSPStateView(
                        state: VSPUiState.error,
                        title: 'Unable to load fee policy',
                        message: 'Please retry to fetch approved gateway rates.',
                        onRetry: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/vsp_primary_button_and_state_view.png'),
        );
      },
    );
  });

  group('Responsive, RTL/LTR, Playground & Accessibility Verification', () {
    test('WCAG AA contrast ratio holds for primary text and accent CTA', () {
      expect(
        _contrastRatio(
          VSPDSSemanticColors.textPrimary,
          VSPDSSemanticColors.background,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          VSPDSSemanticColors.textPrimary,
          VSPDSSemanticColors.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          VSPDSSemanticColors.background,
          VSPDSSemanticColors.accent,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

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

    testWidgets('DesignSystemShowcaseScreen toggles RTL/LTR, 1.6x scale & error state without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: DesignSystemShowcaseScreen(),
        ),
      );

      await tester.tap(find.text('English (LTR)'));
      await tester.pump();
      await tester.tap(find.text('1.6x'));
      await tester.tap(find.text('error'));
      await tester.tap(find.text('Long Text'));
      await tester.pumpAndSettle();

      expect(find.text('VSP Design System Playground'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
