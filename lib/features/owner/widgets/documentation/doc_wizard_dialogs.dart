import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Dialog utilities for the Owner Documentation Wizard.
class DocWizardDialogs {
  const DocWizardDialogs._();

  /// Prompts the owner when attempting to navigate away while uploads are in progress.
  static Future<bool> showCancelUploadConfirmation(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isArabic ? 'إلغاء رفع المستندات؟' : 'Cancel Document Upload?',
          style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? 'جاري رفع المستندات الآن، هل أنت متأكد من رغبتك في إيقاف الرفع والخروج؟'
              : 'Documents are currently uploading. Are you sure you want to stop and exit?',
          style: const TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isArabic ? 'متابعة الرفع' : 'Continue Upload',
              style: const TextStyle(color: VSPColors.accent),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error),
            child: Text(isArabic ? 'إلغاء وخروج' : 'Cancel & Exit'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }
}
