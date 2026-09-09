import 'package:flutter/material.dart';
import '../../../../core/services/owner_document_service.dart';
import 'doc_step_commercial_register.dart';
import 'doc_step_national_id.dart';
import 'doc_step_tax_card.dart';

/// Encapsulates the 3-step PageView for OwnerDocumentationWizard.
class DocWizardStepsPager extends StatelessWidget {
  final PageController pageController;
  final Map<String, String?> uploadedDocUrls;
  final Map<String, bool> uploadingStatus;
  final bool isSaving;

  final void Function(OwnerDocumentType type, String key) onUploadTap;
  final void Function(String key) onDeleteTap;
  final VoidCallback onNextPage;

  const DocWizardStepsPager({
    super.key,
    required this.pageController,
    required this.uploadedDocUrls,
    required this.uploadingStatus,
    required this.isSaving,
    required this.onUploadTap,
    required this.onDeleteTap,
    required this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        DocStepCommercialRegister(
          uploadedUrl: uploadedDocUrls['commercialRegister'],
          isUploading: uploadingStatus['commercialRegister'] ?? false,
          isSaving: isSaving,
          onUploadTap: () => onUploadTap(
            OwnerDocumentType.commercialRegister,
            'commercialRegister',
          ),
          onDeleteTap: () => onDeleteTap('commercialRegister'),
          onNext: onNextPage,
        ),
        DocStepTaxCard(
          uploadedUrl: uploadedDocUrls['taxCard'],
          isUploading: uploadingStatus['taxCard'] ?? false,
          isSaving: isSaving,
          onUploadTap: () => onUploadTap(
            OwnerDocumentType.taxCard,
            'taxCard',
          ),
          onDeleteTap: () => onDeleteTap('taxCard'),
          onNext: onNextPage,
        ),
        DocStepNationalId(
          idFrontUrl: uploadedDocUrls['idFront'],
          idBackUrl: uploadedDocUrls['idBack'],
          isFrontUploading: uploadingStatus['idFront'] ?? false,
          isBackUploading: uploadingStatus['idBack'] ?? false,
          isSaving: isSaving,
          onUploadFrontTap: () => onUploadTap(
            OwnerDocumentType.nationalIdFront,
            'idFront',
          ),
          onDeleteFrontTap: () => onDeleteTap('idFront'),
          onUploadBackTap: () => onUploadTap(
            OwnerDocumentType.nationalIdBack,
            'idBack',
          ),
          onDeleteBackTap: () => onDeleteTap('idBack'),
          onSubmit: onNextPage,
        ),
      ],
    );
  }
}
