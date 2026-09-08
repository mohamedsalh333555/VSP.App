import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class TournamentStepIndicator extends StatelessWidget {
  final int currentStep;

  const TournamentStepIndicator({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.basicsStep,
      l10n.systemStep,
      l10n.schedulingStep,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        children: [
          // Background Connecting Lines
          Positioned(
            left: 28 / 2 + 12,
            right: 28 / 2 + 12,
            top: 28 / 2 - 1,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: currentStep >= 1 ? VSPColors.accent : VSPColors.divider,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: currentStep >= 2 ? VSPColors.accent : VSPColors.divider,
                  ),
                ),
              ],
            ),
          ),
          // Stepper Circles and Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final isActive = i <= currentStep;
              final isCurrent = i == currentStep;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? VSPColors.accent : VSPColors.surface,
                      border: Border.all(
                        color: isActive ? VSPColors.accent : VSPColors.divider,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: i < currentStep
                          ? const Icon(Iconsax.tick_circle_copy, color: Colors.black, size: 16)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.black : VSPColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isCurrent ? VSPColors.accent : VSPColors.textSecondary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 10,
                        ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
