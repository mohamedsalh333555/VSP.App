import 'dart:io';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/image_pick_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/services/owner_document_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../widgets/documentation/doc_wizard_step_indicator.dart';
import '../widgets/documentation/doc_image_source_sheet.dart';
import '../widgets/documentation/doc_under_review_dialog.dart';
import '../widgets/documentation/doc_wizard_dialogs.dart';
import '../widgets/documentation/doc_wizard_hydrator.dart';
import '../widgets/documentation/doc_wizard_steps_pager.dart';

class OwnerDocumentationWizard extends StatefulWidget {
  const OwnerDocumentationWizard({super.key});

  @override
  State<OwnerDocumentationWizard> createState() => _OwnerDocumentationWizardState();
}

class _OwnerDocumentationWizardState extends State<OwnerDocumentationWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false; // blocks the Save button during profile update

  final OwnerDocumentService _documentService = OwnerDocumentService();

  // Document upload state
  final Map<String, String?> _uploadedDocUrls = {
    'commercialRegister': null,
    'taxCard': null,
    'idFront': null,
    'idBack': null,
  };
  final Map<String, bool> _uploadingStatus = {
    'commercialRegister': false,
    'taxCard': false,
    'idFront': false,
    'idBack': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateExistingDocuments();
    });
  }

  void _hydrateExistingDocuments() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    if (user == null) return;

    final hydrated = DocWizardHydrator.hydrate(user.additionalData);

    setState(() {
      _uploadedDocUrls.addAll(hydrated.docUrls);
      _currentStep = hydrated.initialStep;

      if (_currentStep > 0 && _pageController.hasClients) {
        _pageController.jumpToPage(_currentStep);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleUploadSourceSelection(OwnerDocumentType type, String key) async {
    final selection = await showDocSourceActionSheet(context);
    if (selection == null || !mounted) return;
    switch (selection) {
      case DocSourceSelection.camera:
        await _pickAndUpload(type, key, ImageSource.camera);
        break;
      case DocSourceSelection.gallery:
        await _pickAndUpload(type, key, ImageSource.gallery);
        break;
      case DocSourceSelection.file:
        await _pickAndUploadDocumentFile(type, key);
        break;
    }
  }

  Future<void> _pickAndUploadDocumentFile(OwnerDocumentType type, String key) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result == null) return;
      final file = result.files.single;
      XFile xFile;
      if (kIsWeb) {
        if (file.bytes == null) return;
        xFile = XFile.fromData(file.bytes!, name: file.name);
      } else {
        if (file.path == null) return;
        xFile = XFile(file.path!);
      }

      setState(() {
        _uploadingStatus[key] = true;
      });

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.currentUser?.uid;
      if (uid == null) {
        setState(() => _uploadingStatus[key] = false);
        VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);
        return;
      }

      final url = await _documentService.uploadAndSave(
        type: type,
        file: xFile,
        uid: uid,
      );

      if (!mounted) return;
      setState(() {
        _uploadedDocUrls[key] = url;
        _uploadingStatus[key] = false;
      });

      VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.docUploadedSuccess);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingStatus[key] = false;
        });
        VSPFeedback.showError(context, AppLocalizations.of(context)!.uploadFailed(e.toString()));
      }
    }
  }

  Future<void> _pickAndUpload(OwnerDocumentType type, String key, ImageSource source) async {
    try {
      final XFile? pickedFile = await ImagePickService.pick(
        context,
        aspectRatio: CropAspectRatioPreset.original,
        source: source,
      );

      if (!mounted) return;
      if (pickedFile == null) return;

      setState(() {
        _uploadingStatus[key] = true;
      });

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.currentUser?.uid;
      if (uid == null) {
        setState(() => _uploadingStatus[key] = false);
        VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);
        return;
      }

      final url = await _documentService.uploadAndSave(
        type: type,
        file: pickedFile,
        uid: uid,
      );

      // Clean up temporary cached file immediately after upload
      try {
        final tempF = File(pickedFile.path);
        if (await tempF.exists()) {
          await tempF.delete();
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _uploadedDocUrls[key] = url;
        _uploadingStatus[key] = false;
      });

      VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.docUploadedSuccess);
    } catch (e) {
      if (mounted && context.mounted) {
        setState(() {
          _uploadingStatus[key] = false;
        });
        VSPFeedback.showError(context, AppLocalizations.of(context)!.uploadFailed(e.toString()));
      }
    }
  }

  /// Validate required uploads for the current step before advancing.
  void _nextPage() {
    if (_currentStep == 0) {
      // Step 1: commercial register is mandatory.
      if (_uploadedDocUrls['commercialRegister'] == null) {
        VSPFeedback.showError(
          context,
          AppLocalizations.of(context)!.uploadCommRegisterRequired,
        );
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      // Step 2: tax card is mandatory.
      if (_uploadedDocUrls['taxCard'] == null) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showError(
          context,
          isArabic ? 'يرجى رفع البطاقة الضريبية أولاً.' : 'Please upload the tax card first.',
        );
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      // Step 3: both ID sides are mandatory.
      if (_uploadedDocUrls['idFront'] == null) {
        VSPFeedback.showError(
          context,
          AppLocalizations.of(context)!.uploadIdFrontRequired,
        );
        return;
      }
      if (_uploadedDocUrls['idBack'] == null) {
        VSPFeedback.showError(
          context,
          AppLocalizations.of(context)!.uploadIdBackRequired,
        );
        return;
      }
      _saveDocumentsAndShowReview();
    }
  }

  /// Finalise onboarding: write flags, then show under review and navigate.
  Future<void> _saveDocumentsAndShowReview() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.firebaseUser == null) {
        VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);
        setState(() => _isSaving = false);
        return;
      }

      // Submit documents: verificationStatus is strictly 'pending'
      // requiring real Admin approval from Admin Dashboard.
      final bool saved = await authProvider.completeOwnerRegistration(
        verificationStatus: 'pending',
      );

      if (!saved) {
        if (!mounted || !context.mounted) return;
        setState(() => _isSaving = false);
        VSPFeedback.showError(context, AppLocalizations.of(context)!.saveInfoFailed);
        return;
      }

      if (!mounted || !context.mounted) return;
      setState(() => _isSaving = false);

      await showDocUnderReviewDialog(context);

      // Navigate only after the dialog is dismissed.
      if (mounted && context.mounted) {
        context.go('/owner');
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      setState(() => _isSaving = false);
      VSPFeedback.showError(
        context,
        AppLocalizations.of(context)!.saveInfoFailed,
      );
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/owner');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploadingAny = _uploadingStatus.values.any((s) => s == true) || _isSaving;
    return PopScope(
      canPop: !isUploadingAny,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await DocWizardDialogs.showCancelUploadConfirmation(context);
        if (confirm && context.mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/owner');
          }
        }
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: VSPColors.background,
          elevation: 0,
          leadingWidth: 60,
          leading: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: VSPBackButton(onTap: _previousPage),
            ),
          ),
          title: Text(
            AppLocalizations.of(context)!.ownerInformationTitle,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: VSPSpacing.sm),
              DocWizardStepIndicator(currentStep: _currentStep),
              const SizedBox(height: VSPSpacing.md),
              Expanded(
                child: DocWizardStepsPager(
                  pageController: _pageController,
                  uploadedDocUrls: _uploadedDocUrls,
                  uploadingStatus: _uploadingStatus,
                  isSaving: _isSaving,
                  onUploadTap: _handleUploadSourceSelection,
                  onDeleteTap: (key) => setState(() => _uploadedDocUrls[key] = null),
                  onNextPage: _nextPage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
