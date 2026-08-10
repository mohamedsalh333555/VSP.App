import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import 'dart:io';

class VspUploadMainCard extends StatelessWidget {
  final String title;
  final String helper;
  final VoidCallback onTap;
  final bool isLoading;

  const VspUploadMainCard({
    super.key,
    required this.title,
    this.helper = 'JPG, JPEG, PNG less than 10MB',
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
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
                    Text(
                      'Uploading...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VSPColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.imagePlus,
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
                    helper,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VSPColors.textSecondary.withValues(alpha: 0.6),
                        ),
                  ),
                ],
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
          color: thumbnailUrl != null || imageFile != null
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
                image: imageFile != null
                    ? FileImage(imageFile!)
                    : (thumbnailUrl != null
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
                        color: thumbnailUrl != null || imageFile != null
                            ? VSPColors.accent
                            : (isUploading ? VSPColors.warning : VSPColors.textSecondary),
                      ),
                ),
              ],
            ),
          ),
          if (thumbnailUrl != null || imageFile != null)
            Row(
              children: [
                Icon(LucideIcons.checkCircle, color: VSPColors.success, size: 20),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(LucideIcons.trash2, color: VSPColors.error, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            )
          else if (isUploading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.warning),
            )
          else
            Icon(LucideIcons.alertCircle, color: VSPColors.error, size: 20),
        ],
      ),
    );
  }
}
