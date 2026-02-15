import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_upload_widgets.dart';
import 'owner_main_screen.dart';

class AddStadiumWizard extends StatefulWidget {
  final String? stadiumId;
  const AddStadiumWizard({super.key, this.stadiumId});

  @override
  State<AddStadiumWizard> createState() => _AddStadiumWizardState();
}

class _AddStadiumWizardState extends State<AddStadiumWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoadingData = false;

  // Form Controllers
  // Form Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _locationController = TextEditingController();
  
  // State variables for features
  bool? _cafeteria;
  bool? _garage;
  bool? _changingRoom;
  String? _selectedSportType; 
  String? _selectedFloorType;
  String? _selectedBathOption;
  
  // Appointment state
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSplitShift = false;
  TimeOfDay? _breakStartTime;
  TimeOfDay? _breakEndTime;

  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _seatsController = TextEditingController();
  final _notesController = TextEditingController(); // ✅ Owner notes controller
  
  // Image upload state
  final List<Map<String, dynamic>> _images = [];
  bool _isUploading = false;
  bool _isLocationLoading = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.stadiumId != null) {
      _loadStadiumData();
    }
  }

  Future<void> _loadStadiumData() async {
    setState(() => _isLoadingData = true);
    try {
      final data = await _databaseService.getStadiumSnapshot(widget.stadiumId!);
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _locationController.text = data['location'] ?? '';
        _priceController.text = (data['pricePerHour'] ?? 0).toString();
        
        // Note: _capacityController maps to 'seatsCapacity' (Players count in UI logic)
        _capacityController.text = (data['seatsCapacity'] ?? 0).toString();
        
        final features = data['features'] as Map<String, dynamic>? ?? {};
        _selectedFloorType = features['floorType'];
        _selectedSportType = features['sportType']; // Matches UI logic
        _selectedBathOption = features['bathOption'];
        _cafeteria = features['cafeteria'];
        _garage = features['garage'];
        _changingRoom = features['changingRoom'];
        _seatsController.text = features['seats'] ?? '';
        _lengthController.text = features['length'] ?? '';
        _widthController.text = features['width'] ?? '';
        
        final workingHours = features['workingHours'] as Map<String, dynamic>?;
        if (workingHours != null) {
          _startTime = _parseTime(workingHours['start']);
          _endTime = _parseTime(workingHours['end']);
        }
        
        _isSplitShift = features['isSplitShift'] ?? false;
        if (_isSplitShift && features['breakTime'] != null) {
          final breakTime = features['breakTime'] as Map<String, dynamic>;
          _breakStartTime = _parseTime(breakTime['start']);
          _breakEndTime = _parseTime(breakTime['end']);
        }

        // Images
        final allImages = List<String>.from(features['allImages'] ?? []);
        if (allImages.isEmpty && data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
           allImages.add(data['imageUrl']);
        }

        for (var url in allImages) {
          _images.add({
            'file': null,
            'url': url,
            'isUploading': false,
          });
        }

        _notesController.text = data['notes'] ?? ''; // ✅ Load notes
      }
    } catch (e) {
      // Handle error cleanly
      debugPrint('Error loading stadium data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      // Expected: "H:MM AM/PM"
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return null;
      
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _locationController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _seatsController.dispose();
    _notesController.dispose(); // ✅ Dispose notes controller
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      setState(() {
        _locationController.text =
            'Lat: ${position.latitude.toStringAsFixed(2)}, Long: ${position.longitude.toStringAsFixed(2)}';
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch location. Please enter manually.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isMainStart, {bool isBreak = false, bool isStartBreak = true}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.neonGreen,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          if (!isBreak) {
            if (isMainStart) {
              _startTime = picked;
            } else {
              _endTime = picked;
            }
          } else {
            if (isStartBreak) {
              _breakStartTime = picked;
            } else {
              _breakEndTime = picked;
            }
          }
        });
      }
    }
  }

  String _formatTime(TimeOfDay? time, String defaultText) {
    if (time == null) return defaultText;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }


  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final imageEntry = {
          'file': imageFile,
          'url': null,
          'isUploading': true,
        };
        
        setState(() {
          _images.add(imageEntry);
        });
        
        await _uploadImage(imageFile, imageEntry);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _uploadImage(File imageFile, Map<String, dynamic> entry) async {
    setState(() => _isUploading = true);
    
    try {
      final fileName = 'stadium_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _storageService.uploadFile(
        file: imageFile,
        path: 'stadiums/images', // Fixed path: just the folder
        fileName: fileName,      // Filename goes here
      );
      
      if (mounted) {
        setState(() {
          entry['url'] = url;
          entry['isUploading'] = false;
        });
        
        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: AppTheme.neonGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          entry['isUploading'] = false;
          entry['error'] = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _nextPage() {
    if (_currentStep == 0) {
      // Step 1 Validation
      if (_nameController.text.isEmpty ||
          _selectedSportType == null ||
          _priceController.text.isEmpty ||
          _capacityController.text.isEmpty ||
          _startTime == null ||
          _endTime == null ||
          (_isSplitShift && (_breakStartTime == null || _breakEndTime == null)) ||
          _lengthController.text.isEmpty ||
          _widthController.text.isEmpty ||
          _selectedFloorType == null) {
        _showError('Please fill all fields and select floor type');
        return;
      }
    } else if (_currentStep == 1) {
      // Step 2 Validation
      if (_selectedBathOption == null ||
          _cafeteria == null ||
          _garage == null ||
          _changingRoom == null ||
          _seatsController.text.isEmpty) {
        _showError('Please complete all feature selections and seats');
        return;
      }
    }

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  Future<void> _saveStadium() async {
    try {
      // Create stadium document
      final uploadedUrls = _images
          .where((img) => img['url'] != null)
          .map((img) => img['url'] as String)
          .toList();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      if (widget.stadiumId != null) {
         await _databaseService.updateStadium(widget.stadiumId!, {
            'name': _nameController.text,
            'location': _locationController.text,
            'pricePerHour': double.parse(_priceController.text),
            'seatsCapacity': int.parse(_capacityController.text),
            'imageUrl': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
            'features': {
              'floorType': _selectedFloorType,
              'sportType': _selectedSportType,
              'bathOption': _selectedBathOption,
              'cafeteria': _cafeteria,
              'garage': _garage,
              'changingRoom': _changingRoom,
              'seats': _seatsController.text,
              'length': _lengthController.text,
              'width': _widthController.text,
              'workingHours': {
                'start': _startTime?.format(context),
                'end': _endTime?.format(context),
              },
              'isSplitShift': _isSplitShift,
              'breakTime': _isSplitShift ? {
                'start': _breakStartTime?.format(context),
                'end': _breakEndTime?.format(context),
              } : null,
              'allImages': uploadedUrls,
            },
            'notes': _notesController.text.trim(), // ✅ Save notes
         });
      } else {
         await _databaseService.createStadium(
          name: _nameController.text,
          location: _locationController.text,
          pricePerHour: double.parse(_priceController.text),
          seatsCapacity: int.parse(_capacityController.text),
          imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
          ownerId: user.uid,
          features: {
            'floorType': _selectedFloorType,
            'sportType': _selectedSportType,
            'bathOption': _selectedBathOption,
            'cafeteria': _cafeteria,
            'garage': _garage,
            'changingRoom': _changingRoom,
            'seats': _seatsController.text,
            'length': _lengthController.text,
            'width': _widthController.text,
            'workingHours': {
              'start': _startTime?.format(context),
              'end': _endTime?.format(context),
            },
            'isSplitShift': _isSplitShift,
            'breakTime': _isSplitShift ? {
              'start': _breakStartTime?.format(context),
              'end': _breakEndTime?.format(context),
            } : null,
            'allImages': uploadedUrls, 
          },
          notes: _notesController.text.trim(), // ✅ Pass notes at top level
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stadium Added Successfully!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save stadium: $e'),
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
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
    }
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
          
          // Location
          _buildTextField('Location', 'Tap the pin icon to use current location', controller: _locationController, readOnly: true),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isLocationLoading 
                  ? const SizedBox(
                      width: 18, 
                      height: 18, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.my_location, size: 18, color: AppTheme.neonGreen),
              label: Text(
                _isLocationLoading ? 'Fetching location...' : 'Use my current location',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField('Name Stadium', 'Ex: Camp Nou', controller: _nameController),
          const SizedBox(height: 16),
          _buildSportDropdown(),
          const SizedBox(height: 16),
          _buildTextField('Price per hour', '00.0', controller: _priceController),
          const SizedBox(height: 16),
          _buildTextField('Total players for one team', '0', controller: _capacityController),
          const SizedBox(height: 16),
          
          // Time Slots (Appointment)
          const Text('Appointment', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context, true),
                  child: _buildTimeBox(_formatTime(_startTime, 'From 00:00'), isSelected: _startTime != null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context, false),
                  child: _buildTimeBox(_formatTime(_endTime, 'To 00:00'), isSelected: _endTime != null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _isSplitShift = !_isSplitShift),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isSplitShift ? AppTheme.neonGreen.withValues(alpha: 0.1) : Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSplitShift ? AppTheme.neonGreen : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  'Add Break / Split Shift',
                  style: TextStyle(
                    color: _isSplitShift ? AppTheme.neonGreen : Colors.white,
                    fontWeight: _isSplitShift ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          if (_isSplitShift) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectTime(context, false, isBreak: true, isStartBreak: true),
                    child: _buildTimeBox(_formatTime(_breakStartTime, 'Break From'), isSelected: _breakStartTime != null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectTime(context, false, isBreak: true, isStartBreak: false),
                    child: _buildTimeBox(_formatTime(_breakEndTime, 'Break To'), isSelected: _breakEndTime != null),
                  ),
                ),
              ],
            ),
          ],
          
          const Text('Dimensions', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('', 'Length (m)', controller: _lengthController)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('', 'Width (m)', controller: _widthController)),
            ],
          ),
          const SizedBox(height: 16),
          
          const Text('The floor', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSelectBox('Natural grass', _selectedFloorType == 'Natural grass', onTap: () => setState(() => _selectedFloorType = 'Natural grass'))),
              const SizedBox(width: 10),
              Expanded(child: _buildSelectBox('Tartan grass', _selectedFloorType == 'Tartan grass', onTap: () => setState(() => _selectedFloorType = 'Tartan grass'))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildSelectBox('Acrylic floor', _selectedFloorType == 'Acrylic floor', onTap: () => setState(() => _selectedFloorType = 'Acrylic floor'))),
              const SizedBox(width: 10),
              Expanded(child: _buildSelectBox('Other', _selectedFloorType == 'Other', onTap: () => setState(() => _selectedFloorType = 'Other'))),
            ],
          ),

          const SizedBox(height: 24),
          
          // ✅ Stadium Notes Section
          const Text(
            'Stadium notes (visible to players)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 5,
              maxLength: 300,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Example: Please arrive 10 minutes early. Advance payment required. No smoking inside the stadium...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                counterStyle: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
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

          // Bathrooms
          const Text('Bathrooms', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildToggleBox('Yes', _selectedBathOption == 'Yes', onTap: () => setState(() => _selectedBathOption = 'Yes'))),
              const SizedBox(width: 10),
              Expanded(child: _buildToggleBox('No', _selectedBathOption == 'No', onTap: () => setState(() => _selectedBathOption = 'No'))), 
              const SizedBox(width: 10),
              Expanded(child: _buildToggleBox('Showers', _selectedBathOption == 'Showers', onTap: () => setState(() => _selectedBathOption = 'Showers'))),
            ],
          ),
          
          const SizedBox(height: 20),
          // Seats
           _buildTextField('Seats', '0', controller: _seatsController),

          const SizedBox(height: 20),
          // Cafeteria
          _buildYesNoSection('Cafeteria', _cafeteria, onChanged: (val) => setState(() => _cafeteria = val)),

          const SizedBox(height: 20),
          // Garage
          _buildYesNoSection('Garage', _garage, onChanged: (val) => setState(() => _garage = val)),

          const SizedBox(height: 20),
          // Changing room
          _buildYesNoSection('changing room', _changingRoom, onChanged: (val) => setState(() => _changingRoom = val)),

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
          VspUploadMainCard(
            title: 'Click to upload',
            isLoading: _isUploading,
            onTap: _pickImage,
          ),
          
          const SizedBox(height: 20),
          
          // Uploaded List
          if (_images.isNotEmpty)
            ..._images.asMap().entries.map((entry) {
              final index = entry.key;
              final imageMap = entry.value;
              final file = imageMap['file'] as File?;
              final url = imageMap['url'] as String?;
              final isUploading = imageMap['isUploading'] as bool;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VspUploadedItemRow(
                  title: 'Stadium photo ${index + 1}',
                  subtitle: url != null ? 'Uploaded successfully' : (isUploading ? 'Uploading...' : 'Wait for processing'),
                  thumbnailUrl: url,
                  imageFile: file,
                  isUploading: isUploading,
                  onDelete: () => setState(() => _images.removeAt(index)),
                ),
              );
            }),

          const SizedBox(height: 40),
          _buildPrimaryButton('Add Done', _nextPage),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildTextField(String label, String hint, {TextEditingController? controller, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            // focusedBorder is handled by the theme
          ),
        ),
      ],
    );
  }

  Widget _buildSportDropdown() {
    final sports = ['Football', 'Basketball', 'Tennis', 'Volleyball', 'Padel'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add Stadium', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _selectedSportType != null ? AppTheme.neonGreen : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSportType,
              hint: Text('Select Sport', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              dropdownColor: const Color(0xFF1E1E1E),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              items: sports.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSportType = val),
            ),
          ),
        ),
      ],
    );
  }

  // Removed unused _buildDropdownField

  Widget _buildTimeBox(String text, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.neonGreen.withValues(alpha: 0.05) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30), // Pill shape
        border: Border.all(
          color: isSelected ? AppTheme.neonGreen : Colors.white.withValues(alpha: 0.1),
          width: isSelected ? 1.5 : 1,
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
    );
  }
  
  Widget _buildSelectBox(String text, bool isSelected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonGreen.withValues(alpha: 0.05) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30), // Pill shape
          border: Border.all(
            color: isSelected ? AppTheme.neonGreen : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
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

  Widget _buildYesNoSection(String label, bool? value, {required ValueChanged<bool> onChanged}) {
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
