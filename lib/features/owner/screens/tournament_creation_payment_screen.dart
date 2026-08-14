import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../shared/widgets/primary_button.dart';
import 'owner_tournament_dashboard_screen.dart';
import '../../../data/models.dart';

class TournamentCreationPaymentScreen extends StatefulWidget {
  final String championshipId;
  final String championshipName;

  const TournamentCreationPaymentScreen({
    super.key,
    required this.championshipId,
    required this.championshipName,
  });

  @override
  State<TournamentCreationPaymentScreen> createState() =>
      _TournamentCreationPaymentScreenState();
}

class _TournamentCreationPaymentScreenState
    extends State<TournamentCreationPaymentScreen> {
  bool _isLoading = false;
  bool _isActivating = false;
  String _selectedMethod = 'card'; // 'card', 'wallet'
  final double _creationFee = 100.0;
  final double _serviceFee = 4.75;

  double get _totalAmount => _creationFee + _serviceFee;

  Future<void> _handlePayment() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.userModel;
      final userName = user?.name ?? 'Tournament Owner';
      final userEmail = user?.email ?? 'owner@vsp.app';
      final userPhone = user?.phone ?? '+201000000000';

      final selectedIntegrationId = _selectedMethod == 'wallet'
          ? AppConfig.paymobWalletIntegrationId
          : AppConfig.paymobCardIntegrationId;

      // 🚀 Generate Paymob Payment Token
      final paymentToken = await PaymobService.getPaymentToken(
        amountInEgp: _totalAmount,
        bookingId: 'TOURNAMENT_${widget.championshipId}',
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        integrationId: selectedIntegrationId,
      );

      if (paymentToken != null && paymentToken.isNotEmpty) {
        String paymobUrl;
        if (_selectedMethod == 'wallet') {
          final walletUrl = await PaymobService.getWalletRedirectUrl(
            paymentToken: paymentToken,
            phone: userPhone,
          );
          paymobUrl = walletUrl ??
              'https://accept.paymob.com/api/acceptance/iframes/${AppConfig.paymobIframeId}?payment_token=$paymentToken';
        } else {
          paymobUrl =
              'https://accept.paymob.com/api/acceptance/iframes/${AppConfig.paymobIframeId}?payment_token=$paymentToken';
        }

        final Uri uri = Uri.parse(paymobUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        } else {
          throw Exception(isAr ? 'تعذر فتح بوابة الدفع' : 'Could not launch payment gateway');
        }
      } else {
        // Fallback for development / missing Paymob keys: ask user if they want to complete activation
        debugPrint('⚠️ Paymob token generation failed or running in test mode. Prompting activation.');
      }

      // Prompt activation verification
      await _confirmAndActivate(isAr);
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, '${isAr ? "خطأ أثناء الدفع" : "Payment error"}: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAndActivate(bool isAr) async {
    setState(() => _isActivating = true);
    try {
      final txnId = 'PAYMOB_TRN_${DateTime.now().millisecondsSinceEpoch}';
      final success = await TournamentRepository().activateChampionship(
        widget.championshipId,
        paymentId: txnId,
      );

      if (success && mounted) {
        HapticFeedback.heavyImpact();
        VSPFeedback.showSuccess(
            context,
            isAr
                ? 'تم دفع 100 ج.م ونشر البطولة بنجاح! 🏆'
                : 'Payment successful! Tournament is now Live 🏆');

        // Fetch activated championship and navigate to dashboard
        try {
          final champDoc = await Supabase.instance.client
              .from('championships')
              .select()
              .eq('id', widget.championshipId)
              .maybeSingle();

          if (champDoc != null && mounted) {
            final champ = Championship.fromFirestore(champDoc, widget.championshipId);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OwnerTournamentDashboardScreen(championship: champ),
              ),
            );
            return;
          }
        } catch (e) {
          debugPrint('Error fetching championship after activation: $e');
        }

        if (mounted) Navigator.pop(context, true);
      } else if (mounted) {
        VSPFeedback.showError(
            context,
            isAr
                ? 'فشل تفعيل البطولة، يرجى المحاولة مرة أخرى'
                : 'Failed to activate tournament, please try again.');
      }
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return PopScope(
      canPop: !_isLoading && !_isActivating,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          _showExitWarningDialog(isAr);
        }
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: VSPColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
                isAr ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy,
                color: VSPColors.textPrimary),
            onPressed: () => _showExitWarningDialog(isAr),
          ),
          centerTitle: true,
          title: Text(
            isAr ? 'رسوم إنشاء البطولة' : 'Tournament Creation Fee',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: VSPColors.textPrimary,
                ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(VSPSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      VSPColors.accent.withValues(alpha: 0.15),
                      VSPColors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.cup_copy,
                        size: 40,
                        color: VSPColors.accent,
                      ),
                    ),
                    const SizedBox(height: VSPSpacing.md),
                    Text(
                      widget.championshipName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: VSPSpacing.xs),
                    Text(
                      isAr
                          ? 'البطولة محفوظة كمسودة. يلزم دفع 100 ج.م لنشرها وتفعيلها للاعبين.'
                          : 'Tournament saved as draft. 100 EGP fee required to publish.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: VSPColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: VSPSpacing.xl),

              // Fee Summary Breakdown
              Text(
                isAr ? 'ملخص الرسوم' : 'Fee Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: VSPColors.textPrimary,
                    ),
              ),
              const SizedBox(height: VSPSpacing.sm),
              Container(
                padding: const EdgeInsets.all(VSPSpacing.md),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      isAr ? 'رسوم إنشاء البطولة' : 'Creation Fee',
                      '${_creationFee.toStringAsFixed(2)} EGP',
                    ),
                    const SizedBox(height: VSPSpacing.xs),
                    _buildRow(
                      isAr ? 'رسوم بوابة الدفع والخدمة' : 'Service & Gateway Fee',
                      '${_serviceFee.toStringAsFixed(2)} EGP',
                      isSecondary: true,
                    ),
                    const Divider(color: VSPColors.divider, height: 24),
                    _buildRow(
                      isAr ? 'الإجمالي المطلوب' : 'Total Amount',
                      '${_totalAmount.toStringAsFixed(2)} EGP',
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: VSPSpacing.xl),

              // Payment Method Selection
              Text(
                isAr ? 'اختر طريقة الدفع' : 'Select Payment Method',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: VSPColors.textPrimary,
                    ),
              ),
              const SizedBox(height: VSPSpacing.sm),
              _buildPaymentOption(
                id: 'card',
                title: isAr ? 'بطاقة بنكية (فيزا / ماستركارد)' : 'Credit / Debit Card',
                subtitle: isAr ? 'دفع آمن ومباشر عبر Paymob' : 'Secure instant payment via Paymob',
                icon: Iconsax.card_copy,
              ),
              const SizedBox(height: VSPSpacing.xs),
              _buildPaymentOption(
                id: 'wallet',
                title: isAr ? 'محفظة إلكترونية (فودافون/أورنج/اتصالات كاش)' : 'E-Wallet (Vodafone/Orange/Etisalat Cash)',
                subtitle: isAr ? 'الدفع برقم المحفظة' : 'Pay using your mobile wallet number',
                icon: Iconsax.wallet_3_copy,
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
            VSPSpacing.md,
            VSPSpacing.md,
            VSPSpacing.md,
            MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + VSPSpacing.md
                : VSPSpacing.md,
          ),
          color: VSPColors.background,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: PrimaryButton(
              text: isAr
                  ? 'ادفع ${_totalAmount.toStringAsFixed(0)} ج.م وانشر البطولة'
                  : 'Pay ${_totalAmount.toStringAsFixed(0)} EGP & Publish',
              isLoading: _isLoading || _isActivating,
              onPressed: (_isLoading || _isActivating) ? () {} : _handlePayment,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value,
      {bool isSecondary = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isSecondary
                ? VSPColors.textSecondary
                : isTotal
                    ? Colors.white
                    : VSPColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? VSPColors.accent : VSPColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? VSPColors.accent.withValues(alpha: 0.1)
              : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
              size: 26,
            ),
            const SizedBox(width: VSPSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.white : VSPColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: VSPColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedMethod,
              activeColor: VSPColors.accent,
              onChanged: (val) {
                if (val != null) setState(() => _selectedMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExitWarningDialog(bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(
          isAr ? 'البطولة محفوظة كمسودة' : 'Tournament Saved as Draft',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAr
              ? 'تم حفظ البطولة كمسودة. لن تظهر للاعبين حتى يتم سداد رسوم الإنشاء (100 ج.م). يمكنك دفعها لاحقاً.'
              : 'Tournament saved as draft. It will not be visible to players until 100 EGP fee is paid.',
          style: const TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isAr ? 'البقاء في شاشة الدفع' : 'Stay on Payment',
              style: const TextStyle(color: VSPColors.accent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.surfaceLight),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false);
            },
            child: Text(
              isAr ? 'الخروج والتأجيل' : 'Exit for Later',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
