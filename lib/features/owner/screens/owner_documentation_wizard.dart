import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/providers/auth_provider.dart';
import 'owner_stadiums_screen.dart';
import 'owner_main_screen.dart';

class OwnerDocumentationWizard extends StatefulWidget {
  const OwnerDocumentationWizard({super.key});

  @override
  State<OwnerDocumentationWizard> createState() => _OwnerDocumentationWizardState();
}

class _OwnerDocumentationWizardState extends State<OwnerDocumentationWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers (Step 3)
  final _nameController = TextEditingController(text: 'Sifa cc');
  final _phoneController = TextEditingController(text: '+20 1000000232');
  final _emailController = TextEditingController(text: 'sifaccom@gmail.com');
  final _socialController = TextEditingController(text: 'https://wa.me/20100200222...');
  
  // Document upload state
  final Map<String, File?> _uploadedDocs = {
    'taxCard': null,
    'commercialRegister': null,
    'idFront': null,
    'idBack': null,
  };
  final Map<String, String> _uploadedDocUrls = {};
  bool _isUploading = false;
  String? _uploadingDoc;
  
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  
  Future<void> _pickDocument(String docType) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _uploadedDocs[docType] = File(pickedFile.path);
        });
        
        // Upload immediately
        await _uploadDocument(docType, File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _uploadDocument(String docType, File file) async {
    setState(() {
      _isUploading = true;
      _uploadingDoc = docType;
    });
    
    try {
      final fileName = '${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _storageService.uploadFile(
        file: file,
        path: 'owners/docs/$fileName',
      );
      
      if (url != null) {
        setState(() {
          _uploadedDocUrls[docType] = url;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
        _uploadingDoc = null;
      });
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
      // Save documents to user profile
      _saveDocuments();
    }
  }
  
  Future<void> _saveDocuments() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Update user profile with documents
      if (authProvider.firebaseUser != null) {
        await authProvider.updateProfile({
          'documents': _uploadedDocUrls,
          'personalInfo': {
            'name': _nameController.text,
            'phone': _phoneController.text,
            'email': _emailController.text,
            'social': _socialController.text,
          },
          'isRegistrationComplete': true,
        });
      }
      
      // Navigate to Dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OwnerMainScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Information Completed! Welcome to your Dashboard.'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
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
        color: _currentStep == index ? AppTheme.neonGreen : Colors.grey[800],
        borderRadius: BorderRadius.circular(2),
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
          const Text(
            'Upload an image',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          const Text(
            'Commercial register',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isUploading && _uploadingDoc == 'commercialRegister' ? null : () => _pickDocument('commercialRegister'),
            child: _uploadedDocs['commercialRegister'] != null
                ? _buildUploadedDocItem(
                    'Commercial register',
                    _uploadedDocs['commercialRegister']!,
                    _uploadedDocUrls.containsKey('commercialRegister'),
                  )
                : Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.neonGreen, width: 2, style: BorderStyle.solid),
                    ),
                    child: const Center(
                      child: Text(
                        'Click to upload',
                        style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 40),
          _buildPrimaryButton('Save', _nextPage),
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
          const Text(
            'Upload an image',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          GestureDetector(
            onTap: _isUploading && _uploadingDoc == 'idFront' ? null : () => _pickDocument('idFront'),
            child: _buildLargeUploadBox(
              'Click to upload\nJPG, JPEG, PNG less than 10MB',
              _isUploading && _uploadingDoc == 'idFront',
            ),
          ),
          
          const SizedBox(height: 30),
          const Text(
            'National ID Front', 
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
           const SizedBox(height: 10),
          if (_uploadedDocs['idFront'] != null)
            _buildUploadedDocItem('National ID Front', _uploadedDocs['idFront']!, _uploadedDocUrls.containsKey('idFront')),
          
          const SizedBox(height: 20),
          const Text(
            'National ID Back', 
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
           const SizedBox(height: 10),
          if (_uploadedDocs['idBack'] != null)
            _buildUploadedDocItem('National ID Back', _uploadedDocs['idBack']!, _uploadedDocUrls.containsKey('idBack'))
          else
            GestureDetector(
              onTap: _isUploading && _uploadingDoc == 'idBack' ? null : () => _pickDocument('idBack'),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.neonGreen, width: 2),
                ),
                child: const Center(
                  child: Text(
                    'Click to upload ID Back',
                    style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold),
                  ),
                ),
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
          const Text(
            'Add information',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _buildTextField('Owner Name', 'Sifa cc', controller: _nameController),
          const SizedBox(height: 16),
          _buildTextField('Number', '+20 1000000232', controller: _phoneController),
          const SizedBox(height: 16),
          _buildTextField('Email', 'sifaccom@gmail.com', controller: _emailController),
          
          const SizedBox(height: 20),
          const Text('Add Address', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 10),
          // Mock Map
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=800&q=80'), // Map mockup
                fit: BoxFit.cover,
              ),
            ),
             child:  Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white.withOpacity(0.8),
                child: const Text('Add Address', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
           const SizedBox(height: 8),
          const Text('مركز شباب السلام', style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.right),


           const SizedBox(height: 20),
          _buildTextField('Social media', 'https://wa.me/...', controller: _socialController),

          const SizedBox(height: 40),
          _buildPrimaryButton('Save', _nextPage),
        ],
      ),
    );
  }

  // --- Helper Widgets (Reused design patterns) ---

   Widget _buildLargeUploadBox(String text, [bool isUploading = false]) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isUploading ? Colors.grey[700] : AppTheme.neonGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.black),
                  SizedBox(height: 8),
                  Text(
                    'Uploading...',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_outlined, color: Colors.black, size: 40),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
    );
  }
  
  Widget _buildUploadedDocItem(String name, File file, bool uploaded) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D5016).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Document thumbnail
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  uploaded ? 'Uploaded successfully' : 'Processing...',
                  style: TextStyle(
                    color: uploaded ? AppTheme.neonGreen : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (uploaded)
            const Icon(Icons.check_circle, color: AppTheme.neonGreen)
          else
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadedItem(String name, String size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D5016).withOpacity(0.4), // Darker Greenish background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
             child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(size, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                 Text('Click to view', style: TextStyle(color: AppTheme.neonGreen.withOpacity(0.8), fontSize: 10)),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

 Widget _buildTextField(String label, String hint, {TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(30), // Pill shape
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ],
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
            borderRadius: BorderRadius.circular(30), // Pill shape
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
