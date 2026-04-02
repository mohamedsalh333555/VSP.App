import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final BookingDraft bookingDraft;

  const PaymentGatewayScreen({
    super.key,
    required this.bookingDraft,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  bool _isLoading = false;
  final String _selectedPaymentMethod = 'cash';

  void _processPayment() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    try {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.uid;
      
      if (userId == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.sessionExpiredError), backgroundColor: Colors.red));
        return;
      }

      final draftWithPayment = widget.bookingDraft.copyWith(
        paymentMethod: _selectedPaymentMethod,
        paymentTransactionId: 'CASH_${DateTime.now().millisecondsSinceEpoch}',
      );

      final booking = await bookingProvider.createBooking(draftWithPayment, userId);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (booking != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BookingSuccessScreen(booking: booking)));
      } else {
        VSPFeedback.showError(context, bookingProvider.errorMessage ?? l10n.bookingCreateFailed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      VSPFeedback.showError(context, l10n.bookingFailedError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, matchTextDirection: true, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(l10n.confirmBooking, style: Theme.of(context).textTheme.displaySmall),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: VSPColors.accent.withValues(alpha: 0.12)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)),
            ),
          ),
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
            padding: const EdgeInsets.all(VSPSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VSPFadeInItem(delay: const Duration(milliseconds: 100), child: _SectionHeader(title: l10n.bookingSummary)),
                const SizedBox(height: 16),
                VSPFadeInItem(delay: const Duration(milliseconds: 200), child: _BookingSummaryCard(bookingDraft: widget.bookingDraft)),
                const SizedBox(height: 32),
                VSPFadeInItem(delay: const Duration(milliseconds: 300), child: _SectionHeader(title: l10n.paymentMethod)),
                const SizedBox(height: 16),
                VSPFadeInItem(delay: const Duration(milliseconds: 400), child: _buildPaymentMethodChip('cash', l10n.cashPayAtStadium, Icons.payments_outlined)),
                const SizedBox(height: 32),
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 100),
                  child: _SimpleInfoCard(
                    icon: Icons.payments_outlined,
                    title: l10n.cashPayment,
                    subtitle: l10n.cashPaymentDesc,
                  ),
                ),
                const SizedBox(height: 40),
                VSPFadeInItem(delay: const Duration(milliseconds: 600), child: PrimaryButton(text: l10n.confirmBooking, isLoading: _isLoading, onPressed: _processPayment)),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String value, String label, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md, horizontal: VSPSpacing.lg),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: VSPColors.accent, size: 24),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: VSPColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ],
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  final BookingDraft bookingDraft;
  const _BookingSummaryCard({required this.bookingDraft});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.lg),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(VSPRadius.md)),
                child: const Icon(Icons.stadium_outlined, color: VSPColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bookingDraft.stadiumName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                    Text(bookingDraft.bookingType == BookingType.challenge ? l10n.challengeMatch : l10n.privateBooking, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: VSPColors.divider, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(context, Icons.calendar_today_outlined, 
                '${bookingDraft.startTime.day} ${DateFormat.MMM(Localizations.localeOf(context).toString()).format(bookingDraft.startTime)}'),
              _buildSummaryItem(context, Icons.access_time, 
                '${bookingDraft.startTime.hour}:${bookingDraft.startTime.minute.toString().padLeft(2, '0')}'),
              _buildSummaryItem(context, Icons.sports_soccer, 
                bookingDraft.bookingType == BookingType.challenge ? l10n.ranked : l10n.friendly),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(color: VSPColors.background, borderRadius: BorderRadius.circular(VSPRadius.md)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.subtotalAmount, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary)),
                Text('${bookingDraft.totalPrice.toInt()} ${l10n.egCurrency}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.accent, size: 14),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _SimpleInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SimpleInfoCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.xl), border: Border.all(color: VSPColors.divider)),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: VSPColors.accent, size: 48)),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary, height: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
