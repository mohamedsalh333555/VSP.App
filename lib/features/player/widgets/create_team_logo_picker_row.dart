import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Logo picker row used inside [CreateTeamSheet].
///
/// Shows a thumbnail of the currently selected [selectedLogo] (or a
/// placeholder icon) alongside an "Upload / Change Logo" button.
/// Calls [onPickImage] when the button or thumbnail is tapped.
class CreateTeamLogoPickerRow extends StatelessWidget {
  final XFile? selectedLogo;
  final VoidCallback onPickImage;

  const CreateTeamLogoPickerRow({
    super.key,
    required this.selectedLogo,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onPickImage,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider),
              image: selectedLogo != null
                  ? DecorationImage(
                      image: FileImage(File(selectedLogo!.path)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: selectedLogo == null
                ? const Icon(Iconsax.image_copy, color: VSPColors.accent)
                : null,
          ),
          const SizedBox(width: VSPSpacing.md),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: VSPColors.accent,
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.export_3_copy, color: VSPColors.background),
                  const SizedBox(width: VSPSpacing.sm),
                  Text(
                    selectedLogo == null ? l10n.uploadLogo : l10n.changeLogo,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: VSPColors.background,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
