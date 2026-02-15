import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
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
          color: isLoading ? Colors.grey[700] : AppTheme.neonGreen,
          borderRadius: BorderRadius.circular(15),
        ),
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.black),
                    SizedBox(height: 8),
                    Text(
                      'Uploading...',
                      style: TextStyle(color: Colors.black),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: Colors.black, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    helper,
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: thumbnailUrl != null || imageFile != null
              ? AppTheme.neonGreen.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: imageFile != null
                    ? FileImage(imageFile!)
                    : (thumbnailUrl != null
                            ? NetworkImage(thumbnailUrl!)
                            : const AssetImage('assets/images/logo.png'))
                        as ImageProvider,
                fit: BoxFit.cover,
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: thumbnailUrl != null || imageFile != null
                        ? AppTheme.neonGreen
                        : (isUploading ? Colors.orange : Colors.grey),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (thumbnailUrl != null || imageFile != null)
             Row(
               children: [
                 const Icon(Icons.check_circle, color: AppTheme.neonGreen, size: 20),
                 if (onDelete != null) ...[
                   const SizedBox(width: 8),
                   IconButton(
                     icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            )
          else
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
        ],
      ),
    );
  }
}
