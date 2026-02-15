import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/owner_document_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/vsp_upload_widgets.dart';
import 'owner_main_screen.dart';

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
  
  Future<void> _pickAndUpload(OwnerDocumentType type, String key) async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;

      setState(() {
        _uploadingStatus[key] = true;
      });
      
      final url = await _documentService.uploadAndSave(
        type: type,
        file: pickedFile,
      );
      
      if (mounted) {
        setState(() {
          _uploadedDocUrls[key] = url;
          _uploadingStatus[key] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingStatus[key] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          'isRegistrationComplete': true,
        });
      }
      
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E), 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Documents under review',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              content: const Text(
                'Your documents have been submitted and are now being processed. You will receive a response within 12 hours.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); 
                  },
                  child: const Text('OK', style: TextStyle(color: AppTheme.neonGreen)),
                ),
              ],
            );
          },
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const OwnerMainScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: _previousPage,
        ),
        title: const Text(
          'Owner information',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(0),
                const SizedBox(width: 8),
                _buildDot(1),
              ],
            ),
            const SizedBox(height: 20),
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
        color: _currentStep == index ? AppTheme.neonGreen : Colors.grey[800],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStep1BusinessDocs() {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload documents',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          VspUploadMainCard(
            title: 'Click to upload commercial register',
            isLoading: _uploadingStatus['commercialRegister'] ?? false,
            onTap: () => _pickAndUpload(OwnerDocumentType.commercialRegister, 'commercialRegister'),
          ),

          if (_uploadedDocUrls['commercialRegister'] != null) ...[
            const SizedBox(height: 16),
            VspUploadedItemRow(
              title: 'Commercial Register',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _uploadedDocUrls['commercialRegister'],
              onDelete: () => setState(() => _uploadedDocUrls['commercialRegister'] = null),
            ),
          ],

          const SizedBox(height: 40),
          _buildPrimaryButton('Save', _nextPage),
        ],
      ),
    );
  }

  Widget _buildStep2PersonalID() {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload national ID',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          VspUploadMainCard(
            title: 'National ID Front',
            isLoading: _uploadingStatus['idFront'] ?? false,
            onTap: () => _pickAndUpload(OwnerDocumentType.nationalIdFront, 'idFront'),
          ),

          if (_uploadedDocUrls['idFront'] != null) ...[
            const SizedBox(height: 16),
            VspUploadedItemRow(
              title: 'ID Front',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _uploadedDocUrls['idFront'],
              onDelete: () => setState(() => _uploadedDocUrls['idFront'] = null),
            ),
          ],
          
          const SizedBox(height: 24),
          
          VspUploadMainCard(
            title: 'National ID Back',
            isLoading: _uploadingStatus['idBack'] ?? false,
            onTap: () => _pickAndUpload(OwnerDocumentType.nationalIdBack, 'idBack'),
          ),

          if (_uploadedDocUrls['idBack'] != null) ...[
            const SizedBox(height: 16),
            VspUploadedItemRow(
              title: 'ID Back',
              subtitle: 'Uploaded Successfully',
              thumbnailUrl: _uploadedDocUrls['idBack'],
              onDelete: () => setState(() => _uploadedDocUrls['idBack'] = null),
            ),
          ],

          const SizedBox(height: 40),
          _buildPrimaryButton('Save', _nextPage),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
