import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';
import 'doc_explanation_card.dart';

class DocStepCommercialRegister extends StatelessWidget {
  final String? uploadedUrl;
  final bool isUploading;
  final bool isSaving;
  final VoidCallback onUploadTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onNext;

  const DocStepCommercialRegister({
    super.key,
    required this.uploadedUrl,
    required this.isUploading,
    required this.isSaving,
    required this.onUploadTap,
    required this.onDeleteTap,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DocExplanationCard(
            title: isArabic ? 'مرحلة 1: السجل التجاري' : 'Stage 1: Commercial Register',
            description: isArabic
                ? 'يرجى رفع صورة واضحة أو ملف PDF للسجل التجاري الخاص بملعبك/منشأتك. تأكد من أن المستند ساري المفعول ويحتوي على اسم المالك بشكل مقروء.'
                : 'Please upload a clear photo or PDF of your commercial register. Ensure the document is valid and clearly shows the owner\'s name.',
            icon: Iconsax.document_text_copy,
          ),
          const SizedBox(height: VSPSpacing.md),
          VspUploadMainCard(
            title: AppLocalizations.of(context)!.clickToUploadRegister,
            isLoading: isUploading,
            onTap: onUploadTap,
          ),
          if (uploadedUrl != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: AppLocalizations.of(context)!.commercialRegister,
              subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
              thumbnailUrl: uploadedUrl,
              onDelete: onDeleteTap,
            ),
          ],
          const SizedBox(height: VSPSpacing.xxl),
          PrimaryButton(
            text: isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.saveAndContinue,
            onPressed: (isSaving || isUploading) ? null : onNext,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}
