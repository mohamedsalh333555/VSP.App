import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../core/services/owner_document_service.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';
import 'owner_main_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers (Step 3)
  final _nameController = TextEditingController(text: 'Sifa cc');
  final _phoneController = TextEditingController(text: '+20 1000000232');
  final _emailController = TextEditingController(text: 'sifaccom@gmail.com');
  final _socialController = TextEditingController(text: 'https://wa.me/20100200222...');
  
  final OwnerDocumentService _documentService = OwnerDocumentService();

  // State variables for documents
  String? _taxCardUrl;
  bool _isUploadingTaxCard = false;

  String? _commercialRegisterUrl;
  bool _isUploadingCommercial = false;

  // Generic upload handler
  Future<void> _handleUpload(OwnerDocumentType type) async {
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

      final url = await _documentService.uploadAndSave(type: type, filePath: pickedFile.path, uid: '');

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
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
      // Finish Flow -> Go to Dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OwnerMainScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Information Completed! Welcome to your Dashboard.'),
          backgroundColor: VSPColors.accent,
        ),
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
     return SingleChildScrollView(
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
     return SingleChildScrollView(
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _buildTextField('Owner Name', 'Sifa cc', controller: _nameController),
          const SizedBox(height: 16),
          _buildTextField('Number', '+20 1000000232', controller: _phoneController),
          const SizedBox(height: 16),
          _buildTextField('Email', 'sifaccom@gmail.com', controller: _emailController),
          
          const SizedBox(height: 20),
          Text('Add Address', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary)),
          const SizedBox(height: 10),
          // Mock Map
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=800&q=80'), // Map mockup
                fit: BoxFit.cover,
              ),
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
          Text('مركز شباب السلام', style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.right),


           const SizedBox(height: 20),
          _buildTextField('Social media', 'https://wa.me/...', controller: _socialController),

          const SizedBox(height: 40),
          _buildPrimaryButton('Save', _nextPage),
        ],
      ),
    );
  }

  // --- Helper Widgets (Reused design patterns) ---

 Widget _buildTextField(String label, String hint, {TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
        const SizedBox(height: VSPSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md), 
            border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1), width: 0.5),
          ),
          child: TextField(
            controller: controller,
            style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, {bool isEnabled = true}) {
    return PrimaryButton(
      text: text,
      onPressed: isEnabled ? onPressed : () {}, 
    );
  }
}
