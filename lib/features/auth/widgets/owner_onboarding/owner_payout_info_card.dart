import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/custom_text_field.dart';

/// Card component collecting payout details (Instapay, Vodafone Cash, Bank IBAN).
class OwnerPayoutInfoCard extends StatelessWidget {
  final TextEditingController instapayController;
  final TextEditingController vodafoneController;
  final TextEditingController bankController;
  final VoidCallback onSubmitted;

  const OwnerPayoutInfoCard({
    super.key,
    required this.instapayController,
    required this.vodafoneController,
    required this.bankController,
    required this.onSubmitted,
  });

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Iconsax.wallet_1_copy, color: VSPColors.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.payoutInfoTitle,
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            l10n.payoutInfoSubtitle,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildLabel(context, l10n.instapayAddress),
          CustomTextField(
            controller: instapayController,
            hintText: 'username@instapay',
            textInputAction: TextInputAction.next,
            prefixIcon: Iconsax.wallet_1_copy,
          ),
          const SizedBox(height: 16),
          _buildLabel(context, l10n.walletNumber),
          CustomTextField(
            controller: vodafoneController,
            hintText: '01xxxxxxxxx',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: Iconsax.call_copy,
          ),
          const SizedBox(height: 16),
          _buildLabel(context, l10n.bankAccountIban),
          CustomTextField(
            controller: bankController,
            hintText: 'EGxxxxxxxxxxxxxxxxxxxxxx',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmitted(),
            prefixIcon: Iconsax.card_copy,
          ),
        ],
      ),
    );
  }
}
