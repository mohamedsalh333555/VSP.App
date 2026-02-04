import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'owner_stadiums_screen.dart';

class AddStadiumScreen extends StatefulWidget {
  const AddStadiumScreen({super.key});

  @override
  State<AddStadiumScreen> createState() => _AddStadiumScreenState();
}

class _AddStadiumScreenState extends State<AddStadiumScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

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
      // Finish Wizard
      Navigator.pop(context); // Go back to stadiums list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stadium Added Successfully!'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
      // Logic for adding to the list would go here typically
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12), // Pill shape
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
              Expanded(child: _buildToggleBox('No', false)), 
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
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.neonGreen,
              borderRadius: BorderRadius.circular(20), // Card/Pill hybrid
            ),
            child: Column(
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
          
          const SizedBox(height: 20),
          
          // Uploaded List
          _buildUploadedItem('Stadium photo 2', '3.5MB'),
          const SizedBox(height: 10),
          _buildUploadedItem('Stadium photo 1', '3.5MB'),
          const SizedBox(height: 10),
          _buildUploadedItem('Stadium photo 3', '3.5MB'),

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
            borderRadius: BorderRadius.circular(12), // Pill shape
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
            borderRadius: BorderRadius.circular(12), // Pill shape
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
        color: const Color(0xFF1E1E1E), // Dark background
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

  Widget _buildUploadedItem(String name, String size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
             child: const Icon(Icons.image, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Click to view', style: TextStyle(color: AppTheme.neonGreen.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.delete_outline, color: Colors.red),
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
