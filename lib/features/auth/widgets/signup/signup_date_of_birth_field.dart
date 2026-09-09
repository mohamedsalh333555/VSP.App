import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Form field displaying selected date of birth with calendar picker trigger.
class SignupDateOfBirthField extends StatelessWidget {
  final DateTime? dateOfBirth;
  final VoidCallback onTap;

  const SignupDateOfBirthField({
    super.key,
    required this.dateOfBirth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            l10n.dateOfBirth,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: VSPSize.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.input),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 18),
                const SizedBox(width: 12),
                Text(
                  dateOfBirth != null
                      ? '${dateOfBirth!.year}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}'
                      : l10n.dateOfBirthPlaceholder,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: dateOfBirth != null ? VSPColors.textPrimary : VSPColors.textSecondary,
                      ),
                ),
                const Spacer(),
                if (dateOfBirth != null)
                  const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
