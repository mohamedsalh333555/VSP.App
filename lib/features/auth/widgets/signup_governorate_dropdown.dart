import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Reusable governorate dropdown selector for the registration screen.
class SignupGovernorateDropdown extends StatelessWidget {
  const SignupGovernorateDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    const govs = EgyptGovernorates.allGovernorates;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: auth.governorate.isEmpty ? 'Cairo' : auth.governorate,
          dropdownColor: VSPColors.surface,
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.textSecondary),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (String? newValue) {
            if (newValue != null) {
              auth.setGovernorate(newValue);
            }
          },
          items: govs.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
