import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../shared/widgets/custom_text_field.dart';

/// Row containing first name and last name inputs with localized labels.
class SignupNameFields extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;

  const SignupNameFields({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  l10n.firstName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              CustomTextField(
                controller: firstNameController,
                hintText: l10n.firstNameHint,
                textInputAction: TextInputAction.next,
                prefixIcon: Iconsax.user_copy,
                maxLength: 30,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  l10n.lastName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              CustomTextField(
                controller: lastNameController,
                hintText: l10n.lastNameHint,
                textInputAction: TextInputAction.next,
                prefixIcon: Iconsax.user_copy,
                maxLength: 30,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
