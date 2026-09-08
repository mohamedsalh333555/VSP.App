import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';
import 'doc_explanation_card.dart';

class DocStepTaxCard extends StatelessWidget {
  final String? uploadedUrl;
  final bool isUploading;
  final bool isSaving;
  final VoidCallback onUploadTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onNext;

  const DocStepTaxCard({
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
            title: isArabic ? 'مرحلة 2: البطاقة الضريبية' : 'Stage 2: Tax Card',
            description: isArabic
                ? 'يرجى رفع صورة واضحة أو ملف PDF للبطاقة الضريبية الخاصة بالمنشأة. يجب أن يظهر الرقم الضريبي بوضوح للمطابقة والتحقق.'
                : 'Please upload a clear photo or PDF of your facility\'s tax card. The tax number must be clearly visible for verification.',
            icon: Iconsax.document_text_copy,
          ),
          const SizedBox(height: VSPSpacing.md),
          VspUploadMainCard(
            title: isArabic ? 'انقر لرفع البطاقة الضريبية' : 'Click to upload tax card',
            isLoading: isUploading,
            onTap: onUploadTap,
          ),
          if (uploadedUrl != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: isArabic ? 'البطاقة الضريبية' : 'Tax Card',
              subtitle: isArabic ? 'تم الرفع بنجاح' : 'Uploaded Successfully',
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
