import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Pitch conditions and venue policies tab (Punctuality, Reservation, Cancellation, Liability).
class StadiumPitchConditionsTab extends StatelessWidget {
  final Stadium stadium;

  const StadiumPitchConditionsTab({super.key, required this.stadium});

  Widget _buildPolicySection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.accent,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicySection(context, l10n.punctuality, l10n.punctualityPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(context, l10n.reservationDuration, l10n.reservationDurationPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(context, l10n.cancellationPolicyTitle, l10n.cancellationPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(context, l10n.liability, l10n.liabilityPolicy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
