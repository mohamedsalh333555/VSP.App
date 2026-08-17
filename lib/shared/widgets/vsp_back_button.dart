import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class VSPBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const VSPBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: VSPColors.borderLight),
        ),
        child: Icon(
          isArabic ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy,
          color: VSPColors.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}
