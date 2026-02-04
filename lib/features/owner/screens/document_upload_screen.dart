import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
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
          backgroundColor: AppTheme.neonGreen,
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
          
          _buildLargeUploadBox('Tax card\nJPG, JPEG, PNG less than 10MB'),
          const SizedBox(height: 20),
          _buildUploadedItem('Tax card', '2.5MB'),
          
          const SizedBox(height: 30),
          const Text(
            'Commercial register', // Label for next section
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 10),
           _buildUploadedItem('Commercial register', '2.5MB'), 

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
          
          _buildLargeUploadBox('Click to upload\nJPG, JPEG, PNG less than 10MB'),
          
          const SizedBox(height: 30),
          const Text(
            'National ID Front', 
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
           const SizedBox(height: 10),
          _buildUploadedItem('National ID Front', '3.5MB'),
          
          const SizedBox(height: 20),
          const Text(
            'National ID Back', 
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
           const SizedBox(height: 10),
          _buildUploadedItem('National ID Back', '3.5MB'),

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

   Widget _buildLargeUploadBox(String text) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.neonGreen,
        borderRadius: BorderRadius.circular(20), // Card style
      ),
      child: Column(
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
            borderRadius: BorderRadius.circular(12), // Pill shape
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
