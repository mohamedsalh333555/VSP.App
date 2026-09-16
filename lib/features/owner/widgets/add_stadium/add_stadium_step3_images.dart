import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/components/vsp_card.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';

class AddStadiumStep3Images extends StatelessWidget {
  final List<Map<String, dynamic>> images;
  final bool isUploading;
  final bool isSaving;
  final VoidCallback onPickImage;
  final ValueChanged<Map<String, dynamic>> onDeleteImage;
  final VoidCallback onSubmit;

  const AddStadiumStep3Images({
    super.key,
    required this.images,
    required this.isUploading,
    required this.isSaving,
    required this.onPickImage,
    required this.onDeleteImage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        top: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.stadiumGallery,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: VSPSpacing.xs),
          Text(
            AppLocalizations.of(context)!.stadiumPhotosHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
          ),
          const SizedBox(height: 24),
          VspUploadMainCard(
            title: isArabic ? 'إضافة صورة جديدة' : 'Add New Photo',
            helper: isArabic ? 'صور JPG, JPEG, PNG أقل من 10 ميجابايت' : 'JPG, JPEG, PNG less than 10MB',
            isLoading: isUploading,
            onTap: onPickImage,
          ),
          const SizedBox(height: 20),
          if (images.isNotEmpty)
            Column(
              children: images.asMap().entries.map((entry) {
                final index = entry.key;
                final img = entry.value;
                return _buildUploadCard(
                  context,
                  title: isArabic ? 'صورة الملعب ${index + 1}' : 'Stadium Photo ${index + 1}',
                  fileUrl: img['url'],
                  isUploading: img['isUploading'] ?? false,
                  progress: img['progress'] ?? 0,
                  statusLabel: img['statusLabel'],
                  onTap: onPickImage,
                  onDelete: () => onDeleteImage(img),
                  thumbnail: img['url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(VSPRadius.sm),
                          child: CachedNetworkImage(
                            imageUrl: img['url']!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            memCacheWidth: 100,
                            memCacheHeight: 100,
                            placeholder: (_, __) => Container(width: 40, height: 40, color: VSPColors.surface),
                            errorWidget: (_, __, ___) => const Icon(Iconsax.image_copy, size: 20),
                          ),
                        )
                      : (img['file'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(VSPRadius.sm),
                              child: Image.file(img['file']!, width: 40, height: 40, fit: BoxFit.cover),
                            )
                          : null),
                );
              }).toList(),
            ),
          const SizedBox(height: 40),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: 1.0,
            child: PrimaryButton(
              text: isArabic ? 'إرسال الملعب' : 'Submit Stadium',
              onPressed: isSaving ? () {} : onSubmit,
              isLoading: isSaving,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildUploadCard(
    BuildContext context, {
    required String title,
    required String? fileUrl,
    required bool isUploading,
    required int progress,
    String? statusLabel,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    Widget? thumbnail,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return InkWell(
      onTap: fileUrl == null ? onTap : null,
      child: VSPCard(
        padding: const EdgeInsets.all(VSPSpacing.md),
        margin: const EdgeInsets.only(bottom: VSPSpacing.md),
        child: Row(
          children: [
            if (thumbnail != null)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  thumbnail,
                  if (fileUrl != null)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(1),
                        child: const Icon(Iconsax.tick_circle_copy, color: VSPColors.success, size: 14),
                      ),
                    ),
                ],
              )
            else
              Icon(
                fileUrl != null ? Iconsax.tick_circle_copy : Iconsax.export_3_copy,
                color: fileUrl != null ? VSPColors.success : VSPColors.accent,
                size: 32,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (isUploading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.warning),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? "جاري الرفع... $progress%" : "Uploading... $progress%",
                              style: const TextStyle(color: VSPColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(VSPRadius.xs),
                          child: LinearProgressIndicator(
                            value: (progress <= 0) ? null : progress / 100.0,
                            backgroundColor: VSPColors.warning.withValues(alpha: 0.2),
                            color: VSPColors.warning,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    )
                  else if (fileUrl != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.tick_circle_copy, color: VSPColors.success, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          isArabic ? "تم الرفع بنجاح" : "Uploaded successfully",
                          style: const TextStyle(color: VSPColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  else
                    Text(
                      isArabic ? "اضغط للرفع" : "Tap to upload (JPG, PNG <10MB)",
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (fileUrl != null) ...[
              const Icon(Iconsax.tick_circle_copy, color: VSPColors.success, size: 22),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Iconsax.trash_copy, color: VSPColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
