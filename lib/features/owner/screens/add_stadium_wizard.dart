import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import 'package:provider/provider.dart';
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
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _locationController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _seatsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _hasBall = false;
  final _ballPriceController = TextEditingController();

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

  // Step 3: Stadium Images
  final List<Map<String, dynamic>> _images = [];
  bool _isUploading = false;
  bool _isLocationLoading = false;

  // Step 4: Legal Docs
  String? _contractUrl;
  String? _ownerIdUrl;
  bool _isContractUploading = false;
  bool _isOwnerIdUploading = false;
  bool _isSaving = false;

  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
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
        _capacityController.text = (data['seatsCapacity'] ?? 0).toString();
        
        final features = data['features'] as Map<String, dynamic>? ?? {};
        _selectedFloorType = features['floorType'];
        _selectedSportType = features['sportType'];
        _selectedBathOption = features['bathOption'];
        _cafeteria = features['cafeteria'];
        _garage = features['garage'];
        _changingRoom = features['changingRoom'];
        _seatsController.text = features['seats'] ?? '';
        _lengthController.text = features['length'] ?? '';
        _widthController.text = features['width'] ?? '';
        _hasBall = features['hasBall'] ?? false;
        _ballPriceController.text = (features['ballPrice'] ?? 0).toString();
        
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

        final allImages = List<String>.from(features['allImages'] ?? []);
        if (allImages.isEmpty && data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
           allImages.add(data['imageUrl']);
        }

        for (var url in allImages) {
          _images.add({'file': null, 'url': url, 'isUploading': false});
        }

        _notesController.text = data['notes'] ?? '';
        
        // Load Docs if exist (Edit Mode)
        _contractUrl = data['contractUrl'];
        _ownerIdUrl = data['ownerIdUrl'];
      }
    } catch (e) {
      debugPrint('Error loading stadium data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
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
    _nameController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _seatsController.dispose();
    _notesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _locationController.text = 'Lat: ${position.latitude.toStringAsFixed(2)}, Long: ${position.longitude.toStringAsFixed(2)}';
      });
    } catch (e) {
      if(mounted) _showError('Could not fetch location');
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isMainStart, {bool isBreak = false, bool isStartBreak = true}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.neonGreen, onPrimary: Colors.black, surface: Color(0xFF1E1E1E), onSurface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (!isBreak) {
          if (isMainStart) _startTime = picked; else _endTime = picked;
        } else {
          if (isStartBreak) _breakStartTime = picked; else _breakEndTime = picked;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final imageEntry = {'file': imageFile, 'url': null, 'isUploading': true};
        setState(() => _images.add(imageEntry));
        
        // Upload
        final url = await _storageService.uploadFile(file: imageFile, path: 'stadiums/images', fileName: 'std_${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (mounted) {
          setState(() {
            imageEntry['url'] = url;
            imageEntry['isUploading'] = false;
          });
        }
      }
    } catch (e) {
      _showError('Upload failed');
    }
  }

  Future<void> _uploadLegalDoc(bool isContract, String userId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      
      if (result == null || result.files.single.path == null) return;

      setState(() {
        if (isContract) _isContractUploading = true; else _isOwnerIdUploading = true;
      });

      // Use Cloudinary
      final url = await _cloudinaryService.uploadRawFile(
        result.files.single.path!,
        folder: 'stadiums/legal_docs/$userId',
      );

      if (mounted) {
        setState(() {
          if (isContract) _contractUrl = url; else _ownerIdUrl = url;
        });
      }
    } catch (e) {
      _showError('Document upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (isContract) _isContractUploading = false; else _isOwnerIdUploading = false;
        });
      }
    }
  }

  void _nextPage() {
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty || _selectedSportType == null || _priceController.text.isEmpty || _startTime == null || _endTime == null) {
        _showError('Please fill basic info');
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedBathOption == null || _cafeteria == null) {
        _showError('Please select features');
        return;
      }
    } else if (_currentStep == 2) {
      // Validate Images
      if (_images.isEmpty && (widget.stadiumId == null)) {
        _showError('Please upload at least one stadium image');
        return;
      }
    } else if (_currentStep == 3) {
      // Validate Docs
      if (_contractUrl == null || _ownerIdUrl == null) {
        _showError('Please upload both legal documents to verify your stadium');
        return;
      }
      _saveStadium(); // Submit
      return;
    }

    if (_currentStep < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _saveStadium() async {
    setState(() => _isSaving = true);
    try {
      final uploadedUrls = _images.where((img) => img['url'] != null).map((img) => img['url'] as String).toList();
      
      // Get user from Provider for more stable reference
      final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final user = auth.firebaseUser;
      
      debugPrint("Auth user before save: $user");

      if (user == null) {
        _showError("Authentication lost. Please login again.");
        return;
      }

      if (widget.stadiumId != null) {
          // Update Logic
          await _databaseService.updateStadium(widget.stadiumId!, {
            'name': _nameController.text,
            'location': _locationController.text,
            'pricePerHour': double.parse(_priceController.text),
            'seatsCapacity': int.parse(_capacityController.text),
            'imageUrl': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
            'contractUrl': _contractUrl,
            'ownerIdUrl': _ownerIdUrl,
            'notes': _notesController.text,
            'features': {
              'sportType': _selectedSportType,
              'floorType': _selectedFloorType,
              'bathOption': _selectedBathOption,
              'cafeteria': _cafeteria,
              'garage': _garage,
              'changingRoom': _changingRoom,
              'seats': _seatsController.text,
              'length': _lengthController.text,
              'width': _widthController.text,
              'hasBall': _hasBall,
              'ballPrice': double.tryParse(_ballPriceController.text) ?? 0.0,
              'workingHours': {
                'start': _formatTime(_startTime, ''),
                'end': _formatTime(_endTime, ''),
              },
              'allImages': uploadedUrls,
            }
          });
      } else {
          // Create Logic
          final stadiumId = await _databaseService.createStadium(
            name: _nameController.text,
            location: _locationController.text,
            pricePerHour: double.parse(_priceController.text),
            seatsCapacity: int.parse(_capacityController.text),
            imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
            ownerId: user.uid,
            contractUrl: _contractUrl,
            ownerIdUrl: _ownerIdUrl,
            notes: _notesController.text.isEmpty 
              ? "We ensure a professional environment. Please arrive on time. Respect the facility and equipment. Late arrival may result in reduced playing time."
              : _notesController.text,
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
              'hasBall': _hasBall,
              'ballPrice': double.tryParse(_ballPriceController.text) ?? 0.0,
              'workingHours': {
                'start': _formatTime(_startTime, ''),
                'end': _formatTime(_endTime, ''),
              },
              'allImages': uploadedUrls,
            },
          );

          if (stadiumId == null) {
            _showError("Failed to create stadium. Please check your data or permissions.");
            return;
          }
          
          // Update hasStadium flag in AuthProvider/Firestore
          if (mounted) {
            final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
            await auth.updateProfile({'hasStadium': true});
          }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stadium Submitted for Review!', style: TextStyle(color: Colors.black)),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
        Navigator.pop(context); // Return to FacilityOnboardingScreen — StreamBuilder will auto-refresh
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _formatTime(TimeOfDay? time, String defaultText) {
    if (time == null) return defaultText;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary), onPressed: _previousPage),
        title: const Text('Add Stadium', style: TextStyle(color: AppTheme.textPrimary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => _buildDot(index)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Details(),
                  _buildStep2Features(),
                  _buildStep3Images(),
                  _buildStep4Documents(),
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentStep == index ? 24 : 8,
      height: 4,
      decoration: BoxDecoration(
        color: _currentStep == index ? AppTheme.neonGreen : Colors.grey[800],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // --- Steps ---

  Widget _buildStep1Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Location', 'Tap to fetch', controller: _locationController, readOnly: true),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _getCurrentLocation,
            icon: _isLocationLoading ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.my_location),
            label: const Text('Current Location'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E1E), foregroundColor: AppTheme.neonGreen),
          ),
          const SizedBox(height: 16),
          _buildTextField('Stadium Name', 'Ex: Anfield', controller: _nameController),
          const SizedBox(height: 16),
          _buildSportDropdown(),
          const SizedBox(height: 16),
          _buildTextField('Price/Hour', '0.0', controller: _priceController),
          const SizedBox(height: 16),
          _buildTextField('Players/Team', '5', controller: _capacityController),
          const SizedBox(height: 16),
          
          const Text('Working Hours', style: TextStyle(color: Colors.grey)),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => _selectTime(context, true), child: _buildTimeBox(_formatTime(_startTime, 'Start'), isSelected: _startTime != null))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: () => _selectTime(context, false), child: _buildTimeBox(_formatTime(_endTime, 'End'), isSelected: _endTime != null))),
          ]),
          
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildTextField('Length', 'm', controller: _lengthController)),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField('Width', 'm', controller: _widthController)),
          ]),
          
          const SizedBox(height: 16),
          _buildTextField(
            'Notes', 
            'Ex: We ensure a professional environment. Please arrive on time...', 
            controller: _notesController, 
            maxLines: 3
          ),

          const SizedBox(height: 30),
          _buildPrimaryButton('Continue', _nextPage),
        ],
      ),
    );
  }

  Widget _buildStep2Features() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildYesNoSection('Bathrooms', _selectedBathOption == 'Yes', (val) => setState(() => _selectedBathOption = val ? 'Yes' : 'No')),
          const SizedBox(height: 20),
          _buildYesNoSection('Cafeteria', _cafeteria, (val) => setState(() => _cafeteria = val)),
          const SizedBox(height: 20),
          _buildYesNoSection('Garage', _garage, (val) => setState(() => _garage = val)),
          const SizedBox(height: 20),
          _buildYesNoSection('Changing Room', _changingRoom, (val) => setState(() => _changingRoom = val)),
          const SizedBox(height: 20),
          _buildTextField('Seat Count', '0', controller: _seatsController),
          
          const SizedBox(height: 30),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),
          
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Amenities', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          _buildYesNoSection('Ball Available', _hasBall, (val) => setState(() => _hasBall = val)),
          
          if (_hasBall) ...[
            const SizedBox(height: 16),
             _buildTextField('Ball Rental Price (EGP)', '20.0', controller: _ballPriceController),
          ],
          const SizedBox(height: 40),
          _buildPrimaryButton('Continue', _nextPage),
        ],
      ),
    );
  }

  Widget _buildStep3Images() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Stadium Gallery',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'High-quality photos increase your booking rate. Add at least 3 photos of the pitch, facilities, and surroundings.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          
          VspUploadMainCard(
            title: 'Add New Photo',
            isLoading: _isUploading,
            onTap: _pickImage,
          ),
          
          const SizedBox(height: 20),
          
          if (_images.isNotEmpty)
            Column(
              children: _images.asMap().entries.map((entry) {
                final index = entry.key;
                final img = entry.value;
                return _buildUploadCard(
                  title: 'Stadium Photo ${index + 1}',
                  fileUrl: img['url'],
                  isUploading: img['isUploading'] ?? false,
                  onTap: () {}, 
                  onDelete: () => setState(() => _images.remove(img)),
                  thumbnail: img['url'] != null 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(img['url']!, width: 40, height: 40, fit: BoxFit.cover),
                      )
                    : (img['file'] != null 
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(img['file']!, width: 40, height: 40, fit: BoxFit.cover),
                          )
                        : null),
                );
              }).toList(),
            ),

          const SizedBox(height: 40),
          _buildPrimaryButton('Continue', _nextPage),
        ],
      ),
    );
  }

  Widget _buildStep4Documents() {
    final user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify Your Stadium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To activate your stadium and allow players to book, please upload your commercial register and a valid ID. These documents are private and only visible to VSP administrators.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Commercial Register
          _buildUploadCard(
            title: "Commercial Register / Ownership Contract",
            fileUrl: _contractUrl,
            isUploading: _isContractUploading,
            onTap: () => _uploadLegalDoc(true, user?.uid ?? 'unknown'),
            onDelete: () => setState(() => _contractUrl = null),
          ),

          const SizedBox(height: 8),

          // National ID
          _buildUploadCard(
            title: "National ID / Passport",
            fileUrl: _ownerIdUrl,
            isUploading: _isOwnerIdUploading,
            onTap: () => _uploadLegalDoc(false, user?.uid ?? 'unknown'),
            onDelete: () => setState(() => _ownerIdUrl = null),
          ),

          const SizedBox(height: 40),
          _buildPrimaryButton('Submit for Review', _nextPage, isLoading: _isSaving),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              "Your stadium will be reviewed within 24 hours.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildTextField(String label, String hint, {TextEditingController? controller, bool readOnly = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSportDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSportType,
          hint: const Text('Select Sport', style: TextStyle(color: Colors.grey)),
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          items: ['Football', 'Padel', 'Tennis'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: (val) => setState(() => _selectedSportType = val),
        ),
      ),
    );
  }

  Widget _buildTimeBox(String text, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.neonGreen.withOpacity(0.1) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? AppTheme.neonGreen : Colors.transparent),
      ),
      child: Center(child: Text(text, style: TextStyle(color: isSelected ? AppTheme.neonGreen : Colors.white))),
    );
  }

  Widget _buildYesNoSection(String label, bool? value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            _optionBtn('Yes', value == true, () => onChanged(true)),
            const SizedBox(width: 10),
            _optionBtn('No', value == false, () => onChanged(false)),
          ],
        )
      ],
    );
  }

  Widget _optionBtn(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.neonGreen : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: selected ? Colors.black : Colors.white)),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, {bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonGreen, 
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppTheme.neonGreen.withOpacity(0.5),
        ),
        child: isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String? fileUrl,
    required bool isUploading,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    Widget? thumbnail,
  }) {
    return InkWell(
      onTap: fileUrl == null ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: fileUrl != null
                ? Colors.green
                : AppTheme.neonGreen.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            if (thumbnail != null)
              thumbnail
            else
              Icon(
                fileUrl != null ? Icons.check_circle : Icons.upload_file,
                color: fileUrl != null ? Colors.green : AppTheme.neonGreen,
                size: 32,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (isUploading)
                    const Text("Uploading...", style: TextStyle(color: Colors.orange, fontSize: 12))
                  else if (fileUrl != null)
                    const Text("Uploaded successfully", style: TextStyle(color: Colors.green, fontSize: 12))
                  else
                    const Text(
                      "Tap to upload (JPG, PNG <10MB)",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (fileUrl != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
