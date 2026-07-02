import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_upload_widgets.dart';
import '../../../core/services/owner_document_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';

import '../../../core/config/app_config.dart';

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
    'idFront': null,
    'idBack': null,
  };
  final Map<String, bool> _uploadingStatus = {
    'commercialRegister': false,
    'idFront': false,
    'idBack': false,
  };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _showImageSourceActionSheet(OwnerDocumentType type, String key) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: VSPSpacing.md),
            Text(
              AppLocalizations.of(context)!.selectImageSource,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.md),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: VSPColors.accent),
              title: Text(AppLocalizations.of(context)!.camera, style: const TextStyle(color: VSPColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(type, key, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: VSPColors.accent),
              title: Text(AppLocalizations.of(context)!.gallery, style: const TextStyle(color: VSPColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(type, key, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: VSPColors.accent),
              title: const Text('الملفات (PDF / صور)', style: TextStyle(color: VSPColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadDocumentFile(type, key);
              },
            ),
            const SizedBox(height: VSPSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadDocumentFile(OwnerDocumentType type, String key) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
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
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // High quality for verification
      );
      
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
    } else {
      // Step 2: both ID sides are mandatory.
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
  
  /// Finalise onboarding: write flags, then (and ONLY then) show success and navigate.
  /// If the profile update throws, the catch block shows an error and stops — no dialog,
  /// no navigation, no loop back into OwnerDocumentationWizard.
  Future<void> _saveDocumentsAndShowReview() async {
    if (_isSaving) return; // guard against double-tap
    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.firebaseUser == null) {
        VSPFeedback.showError(context, AppLocalizations.of(context)!.sessionExpiredError);
        setState(() => _isSaving = false);
        return;
      }

      final bool autoApprove = AppConfig.autoApproveOwnerInDebug && kDebugMode;

      // Write to Database — if this throws, we skip the success dialog entirely.
      await authProvider.updateProfile({
        'isIdentityVerified': autoApprove,
        'verificationStatus': autoApprove ? 'approved' : 'pending',
        'isRegistrationComplete': true,
      });

      // Only reached when updateProfile succeeds without throwing.
      if (!mounted || !context.mounted) return;
      setState(() => _isSaving = false);

      final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
          icon: Icon(
            autoApprove ? Icons.check_circle_rounded : Icons.access_time_rounded,
            color: VSPColors.accent,
            size: 48,
          ),
          title: Text(
            autoApprove
                ? (isArabic ? '🎉 تم التسجيل بنجاح!' : '🎉 Registration Complete!')
                : (isArabic ? '⏳ قيد المراجعة' : '⏳ Under Review'),
            style: Theme.of(ctx).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          content: Text(
            autoApprove
                ? (isArabic
                    ? AppLocalizations.of(context)!.regCompleteBody
                    : AppLocalizations.of(context)!.regCompleteBody)
                : (isArabic
                    ? 'تم رفع وثائقك بنجاح وهي الآن قيد المراجعة من فريقنا.\n\nيمكنك الآن استكشاف لوحة التحكم وإعداد ملاعبك. ستكون ملاعبك مخفية عن اللاعبين حتى اكتمال التحقق.'
                    : 'Your documents have been submitted and are now under review by our team.\n\nYou can explore the dashboard and set up your stadiums in the meantime. Stadiums will be hidden from players until your account is verified.'),
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: VSPColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: VSPSpacing.md,
            vertical: VSPSpacing.md,
          ),
          actions: [
            PrimaryButton(
              text: isArabic ? 'الذهاب إلى لوحة التحكم' : 'Go to Dashboard',
              height: 48,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );

      // Navigate only after the dialog is dismissed.
      if (mounted && context.mounted) {
        context.go('/owner');
      }
    } catch (e) {
      // updateProfile failed — show error, do NOT navigate, do NOT loop.
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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
          onPressed: _previousPage,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(0),
                const SizedBox(width: VSPSpacing.xs),
                _buildDot(1),
              ],
            ),
            const SizedBox(height: VSPSpacing.md),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BusinessDocs(),
                  _buildStep2PersonalID(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: _currentStep == index ? 24 : 8,
      height: 4,
      decoration: BoxDecoration(
        color: _currentStep == index ? VSPColors.accent : VSPColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStep1BusinessDocs() {
     return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VSPSectionTitle(AppLocalizations.of(context)!.uploadDocuments),
          const SizedBox(height: VSPSpacing.md),
          
          VspUploadMainCard(
            title: AppLocalizations.of(context)!.clickToUploadRegister,
            isLoading: _uploadingStatus['commercialRegister'] ?? false,
            onTap: () => _showImageSourceActionSheet(OwnerDocumentType.commercialRegister, 'commercialRegister'),
          ),

          if (_uploadedDocUrls['commercialRegister'] != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: AppLocalizations.of(context)!.commercialRegister,
              subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
              thumbnailUrl: _uploadedDocUrls['commercialRegister'],
              onDelete: () => setState(() => _uploadedDocUrls['commercialRegister'] = null),
            ),
          ],

          const SizedBox(height: VSPSpacing.xxl),
          PrimaryButton(
            text: _isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.saveAndContinue,
            onPressed: (_isSaving || (_uploadingStatus['commercialRegister'] ?? false))
                ? null
                : _nextPage,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildStep2PersonalID() {
     return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VSPSectionTitle(AppLocalizations.of(context)!.uploadNationalIdTitle),
          const SizedBox(height: VSPSpacing.md),
          
          VspUploadMainCard(
            title: AppLocalizations.of(context)!.nationalIdFront,
            isLoading: _uploadingStatus['idFront'] ?? false,
            onTap: () => _showImageSourceActionSheet(OwnerDocumentType.nationalIdFront, 'idFront'),
          ),

          if (_uploadedDocUrls['idFront'] != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: AppLocalizations.of(context)!.nationalIdFront,
              subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
              thumbnailUrl: _uploadedDocUrls['idFront'],
              onDelete: () => setState(() => _uploadedDocUrls['idFront'] = null),
            ),
          ],
          
          const SizedBox(height: VSPSpacing.md),
          
          VspUploadMainCard(
            title: AppLocalizations.of(context)!.nationalIdBack,
            isLoading: _uploadingStatus['idBack'] ?? false,
            onTap: () => _showImageSourceActionSheet(OwnerDocumentType.nationalIdBack, 'idBack'),
          ),

          if (_uploadedDocUrls['idBack'] != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: AppLocalizations.of(context)!.nationalIdBack,
              subtitle: AppLocalizations.of(context)!.uploadedSuccessfully,
              thumbnailUrl: _uploadedDocUrls['idBack'],
              onDelete: () => setState(() => _uploadedDocUrls['idBack'] = null),
            ),
          ],

          const SizedBox(height: VSPSpacing.xl),
          PrimaryButton(
            text: _isSaving ? AppLocalizations.of(context)!.saving : AppLocalizations.of(context)!.submitDocuments,
            onPressed: (_isSaving ||
                    (_uploadingStatus['idFront'] ?? false) ||
                    (_uploadingStatus['idBack'] ?? false))
                ? null
                : _nextPage,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }


}
