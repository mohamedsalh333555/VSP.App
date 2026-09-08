import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

enum DocSourceSelection {
  camera,
  gallery,
  file,
}

Future<DocSourceSelection?> showDocSourceActionSheet(BuildContext context) async {
  return showModalBottomSheet<DocSourceSelection>(
    context: context,
    backgroundColor: VSPColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: VSPSpacing.md),
          Text(
            AppLocalizations.of(context)!.selectImageSource,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: VSPSpacing.md),
          ListTile(
            leading: const Icon(Iconsax.image_copy, color: VSPColors.accent),
            title: Text(AppLocalizations.of(context)!.camera, style: const TextStyle(color: VSPColors.textPrimary)),
            onTap: () => Navigator.pop(context, DocSourceSelection.camera),
          ),
          ListTile(
            leading: const Icon(Iconsax.image_copy, color: VSPColors.accent),
            title: Text(AppLocalizations.of(context)!.gallery, style: const TextStyle(color: VSPColors.textPrimary)),
            onTap: () => Navigator.pop(context, DocSourceSelection.gallery),
          ),
          ListTile(
            leading: const Icon(Iconsax.document_text_copy, color: VSPColors.accent),
            title: const Text('الملفات (PDF / صور)', style: TextStyle(color: VSPColors.textPrimary)),
            onTap: () => Navigator.pop(context, DocSourceSelection.file),
          ),
          const SizedBox(height: VSPSpacing.md),
        ],
      ),
    ),
  );
}
