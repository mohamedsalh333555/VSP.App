import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_upload_widgets.dart';
import '../../../core/navigation/root_screen.dart';
import '../../../core/services/owner_document_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';

class OwnerDocumentationWizard extends StatefulWidget {
  const OwnerDocumentationWizard({super.key});

  @override
  State<OwnerDocumentationWizard> createState() => _OwnerDocumentationWizardState();
}

class _OwnerDocumentationWizardState extends State<OwnerDocumentationWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
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
              'Select Image Source',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.md),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: VSPColors.accent),
              title: const Text('Camera', style: TextStyle(color: VSPColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(type, key, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: VSPColors.accent),
              title: const Text('Gallery', style: TextStyle(color: VSPColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(type, key, ImageSource.gallery);
              },
            ),
            const SizedBox(height: VSPSpacing.md),
          ],
        ),
      ),
    );
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

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.currentUser?.uid;
      if (uid == null) {
        setState(() => _uploadingStatus[key] = false);
        VSPFeedback.showError(context, 'Session expired. Please sign in again.');
        return;
      }

      final url = await _documentService.uploadAndSave(
        type: type,
        filePath: pickedFile.path,
        uid: uid,
      );
      
      if (!context.mounted) return;
      setState(() {
        _uploadedDocUrls[key] = url;
        _uploadingStatus[key] = false;
      });
      
      VSPFeedback.showSuccess(context, 'Document uploaded successfully!');
    } catch (e) {
      if (mounted && context.mounted) {
        setState(() {
          _uploadingStatus[key] = false;
        });
        VSPFeedback.showError(context, 'Upload failed: $e');
      }
    }
  }

  void _nextPage() {
    if (_currentStep < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _saveDocumentsAndShowReview();
    }
  }
  
  Future<void> _saveDocumentsAndShowReview() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.firebaseUser != null) {
        await authProvider.updateProfile({
          'isIdentityVerified': true,
          'isRegistrationComplete': true,
        });
      }
      
      if (!context.mounted) return;
      
      await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: VSPColors.surface, 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              title: Text(
                'Documents under review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Text(
                'Your documents have been submitted and are now being processed. You will receive a response within 12 hours.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
              actions: [
                PrimaryButton(
                  text: 'OK',
                  height: 48,
                  onPressed: () {
                    Navigator.of(context).pop(); 
                  },
                ),
              ],
            );
          },
        );

        if (mounted && context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const RootScreen()),
            (route) => false,
          );
        }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      VSPFeedback.showError(context, 'Failed to save: $e');
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
          'Owner information',
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
     return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSPSectionTitle('Upload documents'),
          const SizedBox(height: VSPSpacing.md),
          
          VspUploadMainCard(
            title: 'Click to upload commercial register',
            isLoading: _uploadingStatus['commercialRegister'] ?? false,
            onTap: () => _showImageSourceActionSheet(OwnerDocumentType.commercialRegister, 'commercialRegister'),
          ),

          if (_uploadedDocUrls['commercialRegister'] != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: 'Commercial Register',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _uploadedDocUrls['commercialRegister'],
              onDelete: () => setState(() => _uploadedDocUrls['commercialRegister'] = null),
            ),
          ],

          const SizedBox(height: VSPSpacing.xxl),
          PrimaryButton(
            text: 'Save',
            onPressed: _nextPage,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildStep2PersonalID() {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSPSectionTitle('Upload national ID'),
          const SizedBox(height: VSPSpacing.md),
          
          VspUploadMainCard(
            title: 'National ID Front',
            isLoading: _uploadingStatus['idFront'] ?? false,
            onTap: () => _showImageSourceActionSheet(OwnerDocumentType.nationalIdFront, 'idFront'),
          ),

          if (_uploadedDocUrls['idFront'] != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: 'ID Front',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _uploadedDocUrls['idFront'],
              onDelete: () => setState(() => _uploadedDocUrls['idFront'] = null),
            ),
          ],
          
          const SizedBox(height: VSPSpacing.md),
          
          VspUploadMainCard(
            title: 'National ID Back',
            isLoading: _uploadingStatus['idBack'] ?? false,
            onTap: () => _showImageSourceActionSheet(OwnerDocumentType.nationalIdBack, 'idBack'),
          ),

          if (_uploadedDocUrls['idBack'] != null) ...[
            const SizedBox(height: VSPSpacing.md),
            VspUploadedItemRow(
              title: 'ID Back',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _uploadedDocUrls['idBack'],
              onDelete: () => setState(() => _uploadedDocUrls['idBack'] = null),
            ),
          ],

          const SizedBox(height: VSPSpacing.xl),
          PrimaryButton(
            text: 'Save', 
            onPressed: _nextPage,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }


}
