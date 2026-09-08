import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';
import 'doc_explanation_card.dart';

class DocStepNationalId extends StatelessWidget {
  final String? idFrontUrl;
  final String? idBackUrl;
  final bool isFrontUploading;
  final bool isBackUploading;
  final bool isSaving;
  final VoidCallback onUploadFrontTap;
  final VoidCallback onDeleteFrontTap;
  final VoidCallback onUploadBackTap;
  final VoidCallback onDeleteBackTap;
  final VoidCallback onSubmit;

  const DocStepNationalId({
    super.key,
    required this.idFrontUrl,
    required this.idBackUrl,
    required this.isFrontUploading,
    required this.isBackUploading,
    required this.isSaving,
    required this.onUploadFrontTap,
    required this.onDeleteFrontTap,
    required this.onUploadBackTap,
    required this.onDeleteBackTap,
    required this.onSubmit,
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
            title: isArabic ? 'مرحلة 3: بطاقة الرقم القومي' : 'Stage 3: National ID',
            description: isArabic
                ? 'يرجى رفع صورتين واضحتين للوجهين الأمامي والخلفي لبطاقة الرقم القومي الخاصة بمالك المنشأة لإتمام عملية التحقق من الهوية.'
                : 'Please upload clear photos of both the front and back of the owner\'s National ID to complete the verification process.',
            icon: Iconsax.user_copy,
          ),
          const SizedBox(height: VSPSpacing.md),
          VspUploadMainCard(
            title: AppLocalizations.of(context)!.nationalIdFront,
            isLoading: isFrontUploading,
            onTap: onUploadFrontTap,
          ),
          if (idFrontUrl != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: AppLocalizations.of(context)!.nationalIdFront,
              subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
              thumbnailUrl: idFrontUrl,
              onDelete: onDeleteFrontTap,
            ),
          ],
          const SizedBox(height: VSPSpacing.md),
          VspUploadMainCard(
            title: AppLocalizations.of(context)!.nationalIdBack,
            isLoading: isBackUploading,
            onTap: onUploadBackTap,
          ),
          if (idBackUrl != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: AppLocalizations.of(context)!.nationalIdBack,
              subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
              thumbnailUrl: idBackUrl,
              onDelete: onDeleteBackTap,
            ),
          ],
          const SizedBox(height: VSPSpacing.xl),
          PrimaryButton(
            text: isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.submitDocuments,
            onPressed: (isSaving || isFrontUploading || isBackUploading) ? null : onSubmit,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}
