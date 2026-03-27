import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/services/support_service.dart';

class OwnerDebtScreen extends StatelessWidget {
  const OwnerDebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        title: const Text('Invoicing & Debt'),
        backgroundColor: VSPColors.background,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final debt = auth.userModel?.commissionDebt ?? 0.0;
          final isBlocked = auth.userModel?.isSuspended ?? false;
          final threshold = 500.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(VSPSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Debt Status Card
                _buildDebtStatusCard(debt, isBlocked, threshold),
                
                const SizedBox(height: VSPSpacing.xl),
                
                // 2. Explanation
                Text(
                  'How it works',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: VSPSpacing.sm),
                Text(
                  'VSP takes a 5% commission on every completed booking. Once your debt exceeds $threshold EGP, your stadiums will be automatically hidden from search results until payment is confirmed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary,
                  ),
                ),
                
                const SizedBox(height: VSPSpacing.xxl),
                
                // 3. Payment Methods
                VSPCard(
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Methods',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(color: VSPColors.divider, height: 24),
                      _buildPaymentOption(
                        Icons.account_balance_wallet_outlined,
                        'Vodafone Cash',
                        '010XXXXXXX',
                      ),
                      const SizedBox(height: VSPSpacing.md),
                      _buildPaymentOption(
                        Icons.account_balance_outlined,
                        'Bank Transfer (Fawry)',
                        'Account: 123456789',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: VSPSpacing.xxl),
                
                // 4. Action Button
                PrimaryButton(
                  text: 'Upload Payment Receipt',
                  onPressed: () {
                    SupportService().openSupport(context, category: 'Billing & Commission');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebtStatusCard(double debt, bool isBlocked, double threshold) {
    return VSPCard(
      padding: const EdgeInsets.all(VSPSpacing.xl),
      color: isBlocked ? VSPColors.error.withValues(alpha: 0.1) : VSPColors.surface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBlocked ? Icons.warning_rounded : Icons.account_balance_wallet,
                color: isBlocked ? VSPColors.error : VSPColors.accent,
                size: 32,
              ),
              const SizedBox(width: VSPSpacing.sm),
              Text(
                isBlocked ? 'STADIUMS BLOCKED' : 'OUTSTANDING DEBT',
                style: TextStyle(
                  color: isBlocked ? VSPColors.error : VSPColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.md),
          Text(
            '${debt.toStringAsFixed(2)} EGP',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: VSPColors.textPrimary,
            ),
          ),
          const SizedBox(height: VSPSpacing.sm),
          LinearProgressIndicator(
            value: (debt / threshold).clamp(0.0, 1.0),
            backgroundColor: VSPColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(
              isBlocked ? VSPColors.error : VSPColors.accent,
            ),
          ),
          const SizedBox(height: VSPSpacing.xs),
          Text(
            'Limit: $threshold EGP',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(IconData icon, String title, String detail) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.textSecondary),
        const SizedBox(width: VSPSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(detail, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
