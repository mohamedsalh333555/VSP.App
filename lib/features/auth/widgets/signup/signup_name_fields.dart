import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../shared/widgets/custom_text_field.dart';

/// Responsive first/last-name inputs with localized labels.
class SignupNameFields extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;

  const SignupNameFields({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
  });

  Widget _buildNameField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        CustomTextField(
          controller: controller,
          hintText: hint,
          textInputAction: TextInputAction.next,
          prefixIcon: Iconsax.user_copy,
          maxLength: 30,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final firstName = _buildNameField(
      context,
      label: l10n.firstName,
      hint: l10n.firstNameHint,
      controller: firstNameController,
    );
    final lastName = _buildNameField(
      context,
      label: l10n.lastName,
      hint: l10n.lastNameHint,
      controller: lastNameController,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              firstName,
              const SizedBox(height: 12),
              lastName,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: firstName),
            const SizedBox(width: 12),
            Expanded(child: lastName),
          ],
        );
      },
    );
  }
}
