import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class VspUploadMainCard extends StatelessWidget {
  final String title;
  final String? helper;
  final VoidCallback onTap;
  final bool isLoading;

  const VspUploadMainCard({
    super.key,
    required this.title,
    this.helper,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final helperText = helper ?? (isArabic
        ? 'JPG، JPEG، PNG بحجم أقل من 10 ميجابايت'
        : 'JPG, JPEG, PNG less than 10MB');

    return Semantics(
      button: true,
      enabled: !isLoading,
      label: title,
      hint: helperText,
      onTap: isLoading ? null : onTap,
      child: Material(
        color: VSPColors.transparent,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        child: InkWell(
          excludeFromSemantics: true,
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          child: Container(
            width: double.infinity,
            height: 160,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
        ),
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: VSPColors.accent),
                    const SizedBox(height: VSPSpacing.sm),
                    Semantics(
                      liveRegion: true,
                      label: isArabic ? 'جارٍ رفع الملف' : 'Uploading file',
                      child: Text(
                        isArabic ? 'جارٍ رفع الملف' : 'Uploading file',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: VSPColors.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.image_copy,
                      color: VSPColors.textSecondary.withValues(alpha: 0.5), size: 40),
                  const SizedBox(height: VSPSpacing.sm),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: VSPColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    helperText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VSPColors.textSecondary.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }
}

class VspUploadedItemRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final File? imageFile;
  final VoidCallback? onDelete;
  final bool isUploading;

  const VspUploadedItemRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
    this.imageFile,
    this.onDelete,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: (thumbnailUrl?.isNotEmpty ?? false) || imageFile != null
              ? VSPColors.accent.withValues(alpha: 0.3)
              : VSPColors.divider,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VSPColors.background,
              borderRadius: BorderRadius.circular(VSPRadius.sm),
              image: DecorationImage(
                image: (!kIsWeb && imageFile != null)
                    ? FileImage(imageFile!)
                    : ((thumbnailUrl?.isNotEmpty ?? false)
                            ? NetworkImage(thumbnailUrl!)
                            : const AssetImage('assets/images/logo.png'))
                        as ImageProvider,
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {},
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: (thumbnailUrl?.isNotEmpty ?? false) || imageFile != null
                            ? VSPColors.accent
                            : (isUploading ? VSPColors.warning : VSPColors.textSecondary),
                      ),
                ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.warning),
            )
          else if ((thumbnailUrl?.isNotEmpty ?? false) || imageFile != null)
            Row(
              children: [
                const Icon(Iconsax.tick_circle_copy, color: VSPColors.success, size: 20),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: Localizations.localeOf(context).languageCode == 'ar'
                        ? 'حذف الملف'
                        : 'Delete file',
                    icon: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ],
              ],
            )
          else
            const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 20),
        ],
      ),
    );
  }
}
