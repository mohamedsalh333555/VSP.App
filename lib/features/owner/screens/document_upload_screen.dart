import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../core/services/owner_document_service.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../core/navigation/root_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers (Step 3) - Initialized in initState
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _socialController;
  late TextEditingController _addressController;
  
  final OwnerDocumentService _documentService = OwnerDocumentService();

  // State variables for documents
  String? _taxCardUrl;
  bool _isUploadingTaxCard = false;

  String? _commercialRegisterUrl;
  bool _isUploadingCommercial = false;
  
  bool _isSavingInfo = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _socialController = TextEditingController(text: user?.additionalData?['socialMedia'] ?? '');
    _addressController = TextEditingController(text: user?.governorate ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _socialController.dispose();
    _addressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Generic upload handler
  Future<void> _handleUpload(OwnerDocumentType type) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      VSPFeedback.showError(context, 'Session expired. Please sign in again.');
      return;
    }

    try {
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setState(() {
        if (type == OwnerDocumentType.taxCard) {
          _isUploadingTaxCard = true;
        } else if (type == OwnerDocumentType.commercialRegister) {
          _isUploadingCommercial = true;
        }
      });

      final url = await _documentService.uploadAndSave(
        type: type, 
        filePath: pickedFile.path, 
        uid: uid,
      );

      if (mounted) {
        setState(() {
          if (type == OwnerDocumentType.taxCard) {
             _taxCardUrl = url;
          } else if (type == OwnerDocumentType.commercialRegister) {
             _commercialRegisterUrl = url;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, 'Upload failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          if (type == OwnerDocumentType.taxCard) {
             _isUploadingTaxCard = false;
          } else if (type == OwnerDocumentType.commercialRegister) {
             _isUploadingCommercial = false;
          }
        });
      }
    }
  }

  Future<void> _saveFinalInfo() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      VSPFeedback.showError(context, 'Please enter your name');
      return;
    }
    if (phone.isEmpty) {
      VSPFeedback.showError(context, 'Please enter your phone number');
      return;
    }

    setState(() => _isSavingInfo = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.updateProfile({
      'name': name,
      'phone': phone,
      'additionalData': {
        ...authProvider.userModel?.additionalData ?? {},
        'socialMedia': _socialController.text.trim(),
      }
    });

    if (mounted) {
      setState(() => _isSavingInfo = false);
      if (success) {
        VSPFeedback.showSuccess(context, 'Information Saved Successfully!');
        _nextPage();
      } else {
        VSPFeedback.showError(context, 'Failed to save information');
      }
    }
  }

  void _nextPage() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      // Final step: set verification flags then route via RootScreen
      _completeVerification();
    }
  }

  Future<void> _completeVerification() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.updateProfile({
      'isIdentityVerified': true,
      'isRegistrationComplete': true,
    });
    if (!mounted) return;
    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
    } else {
      VSPFeedback.showError(context, 'Failed to complete verification');
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
        backgroundColor: Colors.transparent,
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
            const SizedBox(height: 10),
            // Progress Indicator (3 Dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(0),
                const SizedBox(width: 8),
                _buildDot(1),
                const SizedBox(width: 8),
                _buildDot(2),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable Swipe
                children: [
                  _buildStep1BusinessDocs(),
                  _buildStep2PersonalID(),
                  _buildStep3FinalInfo(),
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
        borderRadius: BorderRadius.circular(VSPRadius.xs),
      ),
    );
  }

  // Step 1: Business Docs (Tax Card, Commercial Register)
  Widget _buildStep1BusinessDocs() {
     return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload documents',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          VspUploadMainCard(
            title: 'Click to upload tax card',
            isLoading: _isUploadingTaxCard,
            onTap: () => _handleUpload(OwnerDocumentType.taxCard),
          ),
          
          if (_taxCardUrl != null) ...[
            const SizedBox(height: 16),
            VspUploadedItemRow(
              title: 'Tax card',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _taxCardUrl,
              onDelete: () => setState(() => _taxCardUrl = null),
            ),
          ],
          
          const SizedBox(height: 30),
          
          VspUploadMainCard(
            title: 'Click to upload commercial register',
            isLoading: _isUploadingCommercial,
            onTap: () => _handleUpload(OwnerDocumentType.commercialRegister),
          ), 
          
          if (_commercialRegisterUrl != null) ...[
            const SizedBox(height: 16),
            VspUploadedItemRow(
              title: 'Commercial register',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _commercialRegisterUrl,
              onDelete: () => setState(() => _commercialRegisterUrl = null),
            ),
          ],

          const SizedBox(height: 40),
          _buildPrimaryButton(
            'Save', 
            _nextPage,
            isEnabled: _taxCardUrl != null && _commercialRegisterUrl != null,
          ),
        ],
      ),
    );
  }

  // Step 2: National ID
  Widget _buildStep2PersonalID() {
     return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload an image',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          Center(
            child: Text(
              "Please use ID Verification Screen", 
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
            ),
          ),

          const SizedBox(height: 40),
          _buildPrimaryButton('Save', _nextPage),
        ],
      ),
    );
  }

  // Step 3: Final Info
  Widget _buildStep3FinalInfo() {
    return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _buildTextField('Owner Name', 'Enter your name', controller: _nameController),
          const SizedBox(height: 16),
          _buildTextField('Number', 'Enter your phone', controller: _phoneController),
          const SizedBox(height: 16),
          _buildTextField('Email', 'Enter your email', controller: _emailController, enabled: false),
          
          const SizedBox(height: 20),
          Text('Add Address', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary)),
          const SizedBox(height: 10),
          // Mock Map Area (Neutralized)
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt, // Replaced fake map mockup image with neutral background
              borderRadius: BorderRadius.circular(VSPRadius.md),
            ),
             child:  Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.xs),
                decoration: BoxDecoration(
                  color: VSPColors.background.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                child: Text(
                  'Add Address', 
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VSPColors.textPrimary, 
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ),
           const SizedBox(height: 8),
          Text(
            _addressController.text.isEmpty ? 'Location not set' : _addressController.text,
            style: Theme.of(context).textTheme.labelSmall,
          ),


           const SizedBox(height: 20),
          _buildTextField('Social media', 'Enter social media link', controller: _socialController),

          const SizedBox(height: 40),
          _buildPrimaryButton(
            'Save', 
            _saveFinalInfo, 
            isLoading: _isSavingInfo,
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets (Reused design patterns) ---

 Widget _buildTextField(String label, String hint, {TextEditingController? controller, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
        const SizedBox(height: VSPSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: enabled ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(VSPRadius.md), 
            border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1), width: 0.5),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: enabled ? VSPColors.textPrimary : VSPColors.textSecondary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, {bool isEnabled = true, bool isLoading = false}) {
    return PrimaryButton(
      text: text,
      isLoading: isLoading,
      onPressed: isEnabled && !isLoading ? onPressed : null, 
    );
  }
}
