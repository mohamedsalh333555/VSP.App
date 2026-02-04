import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/database_service.dart';
import 'owner_stadiums_screen.dart';

class AddStadiumWizard extends StatefulWidget {
  const AddStadiumWizard({super.key});

  @override
  State<AddStadiumWizard> createState() => _AddStadiumWizardState();
}

class _AddStadiumWizardState extends State<AddStadiumWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  
  // State variables for features
  bool _baths = false;
  bool _men = false;
  bool _women = false;
  bool _cafeteria = false;
  bool _jerash = false;
  bool _changingRoom = false;
  
  // Image upload state
  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  bool _isUploading = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
        
        // Upload immediately
        await _uploadImage(File(pickedFile.path));
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
  
  Future<void> _uploadImage(File imageFile) async {
    setState(() => _isUploading = true);
    
    try {
      final fileName = 'stadium_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _storageService.uploadFile(
        file: imageFile,
        path: 'stadiums/images/$fileName',
      );
      
      if (url != null) {
        setState(() {
          _uploadedImageUrls.add(url);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
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
      setState(() => _isUploading = false);
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
      // Save stadium to Firestore
      _saveStadium();
    }
  }
  
  Future<void> _saveStadium() async {
    try {
      // Create stadium document
      await _databaseService.createStadium(
        name: _nameController.text,
        location: 'Cairo, Egypt', // Default or from form
        pricePerHour: double.tryParse(_priceController.text) ?? 0,
        seatsCapacity: int.tryParse(_capacityController.text) ?? 0,
        imageUrl: _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : '',
        features: {
          'baths': _baths,
          'cafeteria': _cafeteria,
          'changingRoom': _changingRoom,
        },
      );
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stadium Added Successfully!'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save stadium: $e'),
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
          'Stadiums information',
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
            // Progress Indicator
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
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                children: [
                  _buildStep1Details(),
                  _buildStep2Features(),
                  _buildStep3Images(),
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

  // Phase 1: Details
  Widget _buildStep1Details() {
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
          _buildTextField('Name Stadium', 'Santiago Bernabeu', controller: _nameController),
          const SizedBox(height: 16),
          _buildDropdownField('Add Stadium', 'Football'),
          const SizedBox(height: 16),
          _buildTextField('Price per hour', '1000 eg', controller: _priceController),
          const SizedBox(height: 16),
          _buildTextField('Total players for one team', '11', controller: _capacityController),
          const SizedBox(height: 16),
          
          // Time Slots (Appointment)
          const Text('Appointment', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTimeBox('From 12AM')),
              const SizedBox(width: 10),
              Expanded(child: _buildTimeBox('To 2AM')),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('Custom', style: TextStyle(color: Colors.white))),
          ),
          
          const SizedBox(height: 16),
          _buildTextField('Dimensions', '68 * 105'),
          const SizedBox(height: 16),
          
          // Floor Type
          const Text('The floor', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSelectBox('Natural grass', true)),
              const SizedBox(width: 10),
              Expanded(child: _buildSelectBox('Tartan grass', false)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildSelectBox('Acrylic floor', false)),
              const SizedBox(width: 10),
              Expanded(child: _buildSelectBox('Other', false)),
            ],
          ),

          const SizedBox(height: 30),
          _buildPrimaryButton('Continue', _nextPage),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Phase 2: Features
  Widget _buildStep2Features() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Other Features',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Baths
          const Text('Baths', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildToggleBox('Men', true)),
              const SizedBox(width: 10),
              Expanded(child: _buildToggleBox('No', false)), // Assuming 'No' meant 'Women' or option? 
                                                             // Figma says: [Men | No | Bathing chair] - Keeping close to Figma text but logical functionality
                                                             // Let's stick to Figma screenshot logic if clear, else standard Yes/No
              const SizedBox(width: 10),
              Expanded(child: _buildToggleBox('Bathing chair', false)),
            ],
          ),
          
          const SizedBox(height: 20),
          // Seats
           _buildTextField('Seats', '50'),

          const SizedBox(height: 20),
          // Cafeteria
          _buildYesNoSection('Cafeteria', true),

          const SizedBox(height: 20),
          // Jerash
          _buildYesNoSection('Jerash', true),

          const SizedBox(height: 20),
          // Changing room
          _buildYesNoSection('changing room', true),

          const SizedBox(height: 40),
          _buildPrimaryButton('Continue', _nextPage),
        ],
      ),
    );
  }

  // Phase 3: Images
  Widget _buildStep3Images() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload an image stadium',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Upload Area
          GestureDetector(
            onTap: _isUploading ? null : _pickImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isUploading ? Colors.grey[700] : AppTheme.neonGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: _isUploading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.black),
                          SizedBox(height: 8),
                          Text(
                            'Uploading...',
                            style: TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: Colors.black, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          'Click to upload',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'JPG, JPEG, PNG less than 10MB',
                          style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Uploaded List
          if (_selectedImages.isNotEmpty)
            ..._selectedImages.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              final uploaded = index < _uploadedImageUrls.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildUploadedItem(
                  'Stadium photo ${index + 1}',
                  file,
                  uploaded,
                ),
              );
            }).toList(),

          const SizedBox(height: 40),
          _buildPrimaryButton('Add Done', _nextPage),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

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

  Widget _buildDropdownField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(30), // Pill shape
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1E1E1E),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              items: [value].map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30), // Pill shape
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
  
  Widget _buildSelectBox(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? Colors.transparent : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30), // Pill shape
        border: Border.all(
          color: isSelected ? AppTheme.neonGreen : Colors.transparent,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? AppTheme.neonGreen : Colors.white, 
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildYesNoSection(String label, bool value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
         const SizedBox(height: 10),
         Row(
           children: [
             Expanded(child: _buildSelectBox('Yes', value)),
             const SizedBox(width: 10),
             Expanded(child: _buildSelectBox('No', !value)),
           ],
         )
      ],
    );
  }

  Widget _buildToggleBox(String label, bool isSelected) {
      return _buildSelectBox(label, isSelected); 
  }

  Widget _buildUploadedItem(String name, File imageFile, bool uploaded) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Image thumbnail
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: FileImage(imageFile),
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
