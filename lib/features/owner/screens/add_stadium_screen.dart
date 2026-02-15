import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models.dart';


class AddStadiumScreen extends StatefulWidget {
  final Stadium? stadium;
  const AddStadiumScreen({super.key, this.stadium});

  @override
  State<AddStadiumScreen> createState() => _AddStadiumScreenState();
}

class _AddStadiumScreenState extends State<AddStadiumScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers & State
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _dimensionsController = TextEditingController();

  // State Variables
  String? _selectedStadiumType; // Null initially
  final List<String> _stadiumTypes = ['Football', 'Basketball', 'Tennis', 'Volleyball', 'Padel'];

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String? _selectedFloorType; // Null initially
  final List<String> _floorTypes = ['Natural grass', 'Tartan grass', 'Acrylic floor', 'Other'];

  bool _isCustomTime = false;

  // Step 2 State
  final _seatsController = TextEditingController();
  String? _selectedBathOption; // Null initially
  bool? _hasCafeteria; // Null initially
  bool? _hasChangingRoom; // Null initially

  // Step 3 Variables (Images)
  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = []; // For future use with Firebase
  final bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.stadium != null) {
      _loadStadiumData();
    }
  }

  void _loadStadiumData() {
    final s = widget.stadium!;
    _nameController.text = s.name;
    _priceController.text = s.pricePerHour.toString();
    _capacityController.text = s.seatsCapacity.toString(); // Using capacity for now
    // _dimensionsController.text = s.dimensions; // Assuming dimension exists or skip
    _selectedStadiumType = s.type;
    // _selectedFloorType = s.floorType; // Assuming floor type exists
    _seatsController.text = s.seatsCapacity.toString();
    
    // Map features if possible
    _hasCafeteria = s.cafeteria > 0;
    _hasJerash = s.hasJerash;
    // _hasChangingRoom = s.hasChangingRoom;
    
    // Baths logic (heuristic)
    // Baths logic (heuristic)
    if (s.baths > 0) {
      _selectedBathOption = 'Men';
    } else {
      _selectedBathOption = 'No';
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
          // _uploadedImageUrls.add(downloadUrl); // Logic to upload to Firebase would go here
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
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
        title: Text(
          widget.stadium != null ? 'Edit Stadium' : 'Stadiums information',
          style: const TextStyle(
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
          
          // Name
          _buildTextField('Name Stadium', 'Santiago Bernabeu', controller: _nameController),
          const SizedBox(height: 16),
          
          // Type Dropdown
          _buildDropdownField(
            'Add Stadium', 
            _selectedStadiumType, 
            _stadiumTypes,
            (val) {
              if (val != null) setState(() => _selectedStadiumType = val);
            }
          ),
          const SizedBox(height: 16),
          
          // Price
          _buildTextField('Price per hour', '1000 eg', controller: _priceController, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          
          // Capacity
          _buildTextField('Total players for one team', '11', controller: _capacityController, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          
          // Time Slots (Appointment)
          const Text('Appointment', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTimeBox(
                  _startTime != null ? _startTime!.format(context) : 'From 12AM',
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 0, minute: 0));
                    if (time != null) setState(() => _startTime = time);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTimeBox(
                  _endTime != null ? _endTime!.format(context) : 'To 2AM',
                   onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 2, minute: 0));
                    if (time != null) setState(() => _endTime = time);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 10),
          _buildCustomTimeToggle(),
          
          const SizedBox(height: 16),
          _buildTextField('Dimensions', '68 * 105', controller: _dimensionsController),
          const SizedBox(height: 16),
          
          // Floor Type (Dynamic Grid)
          const Text('The floor', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          _buildFloorSelector(),

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
              Expanded(child: _buildToggleBox('Men', _selectedBathOption == 'Men', onTap: () => setState(() => _selectedBathOption = 'Men'))),
              const SizedBox(width: 10),
              Expanded(child: _buildToggleBox('No', _selectedBathOption == 'No', onTap: () => setState(() => _selectedBathOption = 'No'))), 
              const SizedBox(width: 10),
              Expanded(child: _buildToggleBox('Bathing chair', _selectedBathOption == 'Bathing chair', onTap: () => setState(() => _selectedBathOption = 'Bathing chair'))),
            ],
          ),
          
          const SizedBox(height: 20),
          // Seats
           _buildTextField('Seats', '50', controller: _seatsController, keyboardType: TextInputType.number),

          const SizedBox(height: 20),
          // Cafeteria
          _buildYesNoSection('Cafeteria', _hasCafeteria, (val) => setState(() => _hasCafeteria = val)),

          const SizedBox(height: 20),
          // Jerash
          _buildYesNoSection('Jerash', _hasJerash, (val) => setState(() => _hasJerash = val)),

          const SizedBox(height: 20),
          // Changing room
          _buildYesNoSection('Changing room', _hasChangingRoom, (val) => setState(() => _hasChangingRoom = val)),

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
            onTap: _pickImage,
            child: Container(
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
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Uploaded List (Dynamic)
          if (_selectedImages.isNotEmpty)
            ..._selectedImages.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildUploadedItem(
                  file, 
                  index, 
                  () {
                    setState(() {
                      _selectedImages.removeAt(index);
                      // Remove from uploaded URLs if logic existed
                    });
                  }
                ),
              );
            }),

          const SizedBox(height: 40),
          _buildPrimaryButton(widget.stadium != null ? 'Save Changes' : 'Add Done', _nextPage),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildTextField(String label, String hint, {TextEditingController? controller, TextInputType? keyboardType}) {
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
            keyboardType: keyboardType,
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

  Widget _buildDropdownField(String label, String? value, List<String> items, Function(String?) onChanged) {
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
              hint: const Text('Select Option', style: TextStyle(color: Colors.grey)),
              dropdownColor: const Color(0xFF1E1E1E),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              items: items.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTimeToggle() {
      return GestureDetector(
        onTap: () {
            setState(() => _isCustomTime = !_isCustomTime);
        },
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
            color: _isCustomTime ? AppTheme.neonGreen.withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
            border: Border.all(color: _isCustomTime ? AppTheme.neonGreen : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
            child: Text(
                'Custom',
                style: TextStyle(
                    color: _isCustomTime ? AppTheme.neonGreen : Colors.white,
                    fontWeight: FontWeight.bold,
                )
            ),
            ),
        ),
    );
  }

  Widget _buildTimeBox(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Dark background
          borderRadius: BorderRadius.circular(30), // Pill shape
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Center(
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ),
    );
  }
  
  Widget _buildSelectBox(String text, bool isSelected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYesNoSection(String label, bool? value, Function(bool) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
         const SizedBox(height: 10),
         Row(
           children: [
             Expanded(child: _buildSelectBox('Yes', value == true, onTap: () => onChanged(true))),
             const SizedBox(width: 10),
             Expanded(child: _buildSelectBox('No', value == false, onTap: () => onChanged(false))),
           ],
         )
      ],
    );
  }

  Widget _buildToggleBox(String label, bool isSelected, {VoidCallback? onTap}) {
      return _buildSelectBox(label, isSelected, onTap: onTap); 
  }

  Widget _buildUploadedItem(File imageFile, int index, VoidCallback onDelete) {
    return GestureDetector(
      onTap: () {
        // Show Full Image
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            child: InteractiveViewer(
              child: Image.file(imageFile, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
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
                  Text('Stadium photo ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Click to view', style: TextStyle(color: AppTheme.neonGreen.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _floorTypes.map((type) {
        final isSelected = _selectedFloorType == type;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 60) / 2, // 2 items per row logic
          child: GestureDetector(
            onTap: () => setState(() => _selectedFloorType = type),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? Colors.transparent : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? AppTheme.neonGreen : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? AppTheme.neonGreen : Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
