import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/ui/tokens/vsp_design_tokens.dart';
import '../../core/ui/vsp_ui.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/vsp_payment_summary_card.dart';

/// Internal developer-only Design System Showcase & Interactive Playground
/// (never exposed in release builds).
class DesignSystemShowcaseScreen extends StatefulWidget {
  const DesignSystemShowcaseScreen({super.key});

  @override
  State<DesignSystemShowcaseScreen> createState() =>
      _DesignSystemShowcaseScreenState();
}

class _DesignSystemShowcaseScreenState
    extends State<DesignSystemShowcaseScreen> {
  bool _isArabic = true;
  double _textScale = 1.0;
  VSPUiState? _previewState;
  bool _isButtonLoading = false;
  bool _isButtonDisabled = false;
  bool _useLongText = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_textScale),
        ),
        child: Scaffold(
          backgroundColor: VSPDSSemanticColors.background,
          appBar: AppBar(
            backgroundColor: VSPDSSemanticColors.surface,
            title: Text(
              _isArabic
                  ? 'معرض نظام تصميم VSP'
                  : 'VSP Design System Playground',
              style: const TextStyle(color: VSPDSSemanticColors.textPrimary),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(VSPDSSpacing.md),
              children: [
              _buildControlsCard(),
              const SizedBox(height: VSPDSSpacing.md),
              VSPSectionHeader(
                title: _isArabic ? 'حالات الواجهة' : 'UI State Views',
              ),
              const SizedBox(height: VSPDSSpacing.sm),
              _buildStatePreview(),
              const SizedBox(height: VSPDSSpacing.md),
              VSPSectionHeader(
                title: _isArabic ? 'ملخص الدفع المعتمد' : 'Financial Summary',
              ),
              const SizedBox(height: VSPDSSpacing.sm),
              VSPPaymentSummaryCard(
                baseAmount: 100.00,
                playerVspFee: 5.00,
                gatewayFee: 5.52,
                totalAmount: 110.52,
                paymentStatus: _useLongText
                    ? (_isArabic
                        ? 'تم دفع كامل مبلغ الحجز والرسوم بنجاح عبر البطاقة البنكية'
                        : 'Full booking amount and gateway fees paid successfully')
                    : (_isArabic ? 'مدفوع' : 'Paid'),
                isArabic: _isArabic,
              ),
              const SizedBox(height: VSPDSSpacing.md),
              VSPSectionHeader(
                title: _isArabic ? 'الأزرار التفاعلية' : 'Action Buttons',
              ),
              const SizedBox(height: VSPDSSpacing.sm),
              PrimaryButton(
                text: _useLongText
                    ? (_isArabic
                        ? 'تأكيد الحجز والدفع الإلكتروني الآمن الآن'
                        : 'Confirm Booking and Proceed to Secure Checkout')
                    : (_isArabic ? 'ادفع الآن' : 'Pay Now'),
                isLoading: _isButtonLoading,
                onPressed: _isButtonDisabled ? null : () {},
              ),
              const SizedBox(height: VSPDSSpacing.sm),
              Wrap(
                spacing: VSPDSSpacing.xs,
                runSpacing: VSPDSSpacing.xs,
                children: [
                  VSPStatusPill(
                    label: _isArabic ? 'نشط' : 'Active',
                    color: VSPDSSemanticColors.success,
                  ),
                  VSPStatusPill(
                    label: _isArabic ? 'قيد الانتظار' : 'Pending',
                    color: VSPDSSemanticColors.warning,
                  ),
                  VSPStatusPill(
                    label: _isArabic ? 'خطأ' : 'Error',
                    color: VSPDSSemanticColors.error,
                  ),
                  VSPStatusPill(
                    label: _isArabic ? 'معلومة' : 'Info',
                    color: VSPDSSemanticColors.info,
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Container(
      padding: const EdgeInsets.all(VSPDSSpacing.md),
      decoration: BoxDecoration(
        color: VSPDSSemanticColors.surface,
        borderRadius: BorderRadius.circular(VSPDSRadius.lg),
        border: Border.all(color: VSPDSSemanticColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: VSPDSSpacing.xs,
            runSpacing: VSPDSSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text('العربية (RTL)'),
                selected: _isArabic,
                onSelected: (_) => setState(() => _isArabic = true),
              ),
              ChoiceChip(
                label: const Text('English (LTR)'),
                selected: !_isArabic,
                onSelected: (_) => setState(() => _isArabic = false),
              ),
            ],
          ),
          const SizedBox(height: VSPDSSpacing.sm),
          Wrap(
            spacing: VSPDSSpacing.xs,
            runSpacing: VSPDSSpacing.xs,
            children: [1.0, 1.3, 1.6].map((scale) {
              return ChoiceChip(
                label: Text('${scale}x'),
                selected: _textScale == scale,
                onSelected: (_) => setState(() => _textScale = scale),
              );
            }).toList(),
          ),
          const SizedBox(height: VSPDSSpacing.sm),
          Wrap(
            spacing: VSPDSSpacing.xs,
            runSpacing: VSPDSSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text('ready'),
                selected: _previewState == null,
                onSelected: (_) => setState(() => _previewState = null),
              ),
              ...VSPUiState.values.map((state) {
                return ChoiceChip(
                  label: Text(state.name),
                  selected: _previewState == state,
                  onSelected: (_) => setState(() => _previewState = state),
                );
              }),
            ],
          ),
          const SizedBox(height: VSPDSSpacing.sm),
          Wrap(
            spacing: VSPDSSpacing.xs,
            runSpacing: VSPDSSpacing.xs,
            children: [
              FilterChip(
                label: Text(_isArabic ? 'جاري التحميل' : 'Button Loading'),
                selected: _isButtonLoading,
                onSelected: (v) => setState(() => _isButtonLoading = v),
              ),
              FilterChip(
                label: Text(_isArabic ? 'معطّل' : 'Button Disabled'),
                selected: _isButtonDisabled,
                onSelected: (v) => setState(() => _isButtonDisabled = v),
              ),
              FilterChip(
                label: Text(_isArabic ? 'نص طويل' : 'Long Text'),
                selected: _useLongText,
                onSelected: (v) => setState(() => _useLongText = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatePreview() {
    final previewState = _previewState;
    if (previewState == null) {
      return Container(
        padding: const EdgeInsets.all(VSPDSSpacing.md),
        decoration: BoxDecoration(
          color: VSPDSSemanticColors.surface,
          borderRadius: BorderRadius.circular(VSPDSRadius.md),
          border: Border.all(color: VSPDSSemanticColors.borderSubtle),
        ),
        child: Text(
          _isArabic
              ? 'الحالة جاهزة — جميع العناصر متصلة بالـ Tokens المركزية.'
              : 'Ready state — all components wired to canonical V2 tokens.',
          style: const TextStyle(color: VSPDSSemanticColors.textPrimary),
        ),
      );
    }

    return VSPStateView(
      state: previewState,
      title: _useLongText
          ? (_isArabic
              ? 'عنوان طويل لاختبار التفاف النصوص في حالات التحميل والفراغ والخطأ'
              : 'Long title to verify text wrapping across loading, empty, and error states')
          : (_isArabic ? 'معاينة الحالة' : 'State Preview'),
      message: _isArabic
          ? 'رسالة توضيحية متوافقة مع نظام التصميم.'
          : 'Supporting message aligned with VSP Design System.',
      onRetry: () => setState(() => _previewState = null),
    );
  }
}
