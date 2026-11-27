import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';
import '../../core/ui/vsp_ui.dart';
import '../../core/utils/vsp_financial_formatter.dart';
import '../../data/models.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/vsp_payment_summary_card.dart';

/// Internal developer-only Design System Showcase (never exposed in release builds).
class DesignSystemShowcaseScreen extends StatelessWidget {
  const DesignSystemShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return VSPScaffold(
      backgroundColor: VSPDSSemanticColors.background,
      appBar: AppBar(
        backgroundColor: VSPDSSemanticColors.background,
        title: const Text('VSP Design System V2 Showcase'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VSPDSSpacing.pageHorizontal),
        children: [
          const VSPSectionHeader(
            title: 'Semantic Colors',
            subtitle: 'Canonical VSPDSColors -> VSPDSSemanticColors',
          ),
          const Wrap(
            spacing: VSPDSSpacing.xs,
            runSpacing: VSPDSSpacing.xs,
            children: [
              _Swatch('Background', VSPDSSemanticColors.background),
              _Swatch('Surface', VSPDSSemanticColors.surface),
              _Swatch('Raised', VSPDSSemanticColors.surfaceRaised),
              _Swatch('Accent', VSPDSSemanticColors.accent),
              _Swatch('Error', VSPDSSemanticColors.error),
              _Swatch('Warning', VSPDSSemanticColors.warning),
              _Swatch('Info', VSPDSSemanticColors.info),
            ],
          ),
          const SizedBox(height: VSPDSSpacing.section),
          const VSPSectionHeader(
            title: 'Status Pills',
            subtitle: 'Localized booking & payment states',
          ),
          Wrap(
            spacing: VSPDSSpacing.xs,
            runSpacing: VSPDSSpacing.xs,
            children: [
              VSPStatusPill(
                label: VSPFinancialFormatter.localizeBookingStatus(
                  BookingStatus.confirmed,
                  isArabic: isAr,
                ),
                color: VSPFinancialFormatter.statusColor(BookingStatus.confirmed),
              ),
              VSPStatusPill(
                label: VSPFinancialFormatter.localizeBookingStatus(
                  BookingStatus.pending,
                  isArabic: isAr,
                ),
                color: VSPFinancialFormatter.statusColor(BookingStatus.pending),
              ),
              VSPStatusPill(
                label: VSPFinancialFormatter.localizeBookingStatus(
                  BookingStatus.cancelled,
                  isArabic: isAr,
                ),
                color: VSPFinancialFormatter.statusColor(BookingStatus.cancelled),
              ),
            ],
          ),
          const SizedBox(height: VSPDSSpacing.section),
          const VSPSectionHeader(
            title: 'Payment Summary Pattern',
            subtitle: '100 EGP reference booking (5% player + 2.4%+3 Paymob)',
          ),
          VSPPaymentSummaryCard(
            baseAmount: 100,
            playerVspFee: 5,
            gatewayFee: 5.66,
            totalAmount: 110.66,
            paymentStatus: 'paid',
            isArabic: isAr,
          ),
          const SizedBox(height: VSPDSSpacing.section),
          const VSPSectionHeader(
            title: 'Buttons & States',
            subtitle: 'Standard 56dp pill actions & state views',
          ),
          PrimaryButton(
            text: isAr ? 'زر أساسي' : 'Primary Action',
            onPressed: () {},
          ),
          const SizedBox(height: VSPDSSpacing.sm),
          const PrimaryButton(
            text: 'Loading State',
            isLoading: true,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;

  const _Swatch(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.all(VSPDSSpacing.xs),
      decoration: BoxDecoration(
        color: VSPDSSemanticColors.surface,
        borderRadius: BorderRadius.circular(VSPDSRadius.sm),
        border: Border.all(color: VSPDSSemanticColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(VSPDSRadius.xs),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: VSPDSSemanticColors.textPrimary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
