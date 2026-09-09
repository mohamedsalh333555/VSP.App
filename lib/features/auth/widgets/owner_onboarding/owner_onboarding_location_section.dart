import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Location selector with GPS auto-detect and fallback dropdown for Owner Onboarding.
class OwnerOnboardingLocationSection extends StatelessWidget {
  final String selectedGovernorate;
  final bool isFetchingLocation;
  final bool isLocationFallbackActive;
  final ValueChanged<String> onGovernorateChanged;
  final VoidCallback onAutoDetectTapped;

  const OwnerOnboardingLocationSection({
    super.key,
    required this.selectedGovernorate,
    required this.isFetchingLocation,
    required this.isLocationFallbackActive,
    required this.onGovernorateChanged,
    required this.onAutoDetectTapped,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const govs = EgyptGovernorates.allGovernorates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.governorate, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500)),
            const Spacer(),
            if (isFetchingLocation)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent))
            else
              GestureDetector(
                onTap: onAutoDetectTapped,
                child: const Icon(Iconsax.gps_copy, color: VSPColors.accent, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLocationFallbackActive)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: VSPColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.error.withValues(alpha: 0.5)),
            ),
            child: Text(
              l10n.locationAutoDetectFailed,
              style: const TextStyle(color: VSPColors.error, fontSize: 12, fontWeight: FontWeight.bold, height: 1.5),
            ),
          ),
        Container(
          height: VSPSize.inputHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.input),
            border: Border.all(
              color: isLocationFallbackActive ? VSPColors.accent : VSPColors.accent.withValues(alpha: 0.1),
              width: isLocationFallbackActive ? 2.0 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedGovernorate,
              dropdownColor: VSPColors.surface,
              icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.textSecondary),
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (v) {
                if (v != null) onGovernorateChanged(v);
              },
              items: govs
                  .map<DropdownMenuItem<String>>((v) => DropdownMenuItem<String>(
                        value: v,
                        child: Text(v, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
