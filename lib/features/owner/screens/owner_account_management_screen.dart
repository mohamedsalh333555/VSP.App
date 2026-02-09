import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
// import '../../player/screens/player_home_screen.dart'; // Not needed if we duplicate local logic for visual consistency

class OwnerAccountManagementScreen extends StatefulWidget {
  const OwnerAccountManagementScreen({super.key});

  @override
  State<OwnerAccountManagementScreen> createState() => _OwnerAccountManagementScreenState();
}

class _OwnerAccountManagementScreenState extends State<OwnerAccountManagementScreen> {
  // Mock Data
  final TextEditingController _nameController = TextEditingController(text: 'Sal adc');
  final TextEditingController _phoneController = TextEditingController(text: '+20 01111000222');
  final TextEditingController _emailController = TextEditingController(text: 'hana.mohamed@gmail.com');
  final TextEditingController _socialController = TextEditingController(text: 'https://www.facebook.com/search/pages/?q=VSPS&sde=Abrg...'); // Truncated as per image
  
  List<Stadium> _stadiums = [];

  @override
  void initState() {
    super.initState();
    // Mock Stadiums Matches the screenshot
    _stadiums = [
      Stadium(
        id: '1',
        name: 'Santiago Bernabeu 11 VS 11 Football',
        location: 'Madrid',
        imageUrl: 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800&h=600&fit=crop&q=80',
        type: 'Football',
        size: '11 VS 11',
        baths: 5,
        cafeteria: 2,
        seatsCapacity: 90000,
        pricePerHour: 1000000,
        area: 'Jerash',
        isFavorite: false,
        address: 'Madrid, Spain',
        pitchCondition: 'Excellent',
      ),
      // Add more if needed for horizontal scroll demo
      Stadium(
         id: '2',
         name: 'Salam Acd',
         location: 'Aswan',
         imageUrl: 'https://images.unsplash.com/photo-1624880357913-a8539238245b?w=800&h=600&fit=crop&q=80',
         type: 'Volleyball',
         size: '8 VS 8',
         baths: 2,
         cafeteria: 1,
         seatsCapacity: 50,
         pricePerHour: 250,
         area: 'Jerash',
         isFavorite: false,
         address: 'Aswan, Egypt',
         pitchCondition: 'Good',
       ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Pure Dark
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Space for button
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stadium Selector (Horizontal List)
            SizedBox(
              height: 220, // Height for card + padding
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                scrollDirection: Axis.horizontal,
                itemCount: _stadiums.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 300, // Fixed width for horizontal items
                    margin: const EdgeInsets.only(right: 16),
                    child: _buildStadiumCard(_stadiums[index]),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),

            // 2. Personal Info Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel('Owner Name'),
                   _buildTextField(_nameController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Number'),
                   _buildTextField(_phoneController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Email'),
                   _buildTextField(_emailController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Add Address'),
                   // Map Widget Placeholder
                   Container(
                     height: 150,
                     width: double.infinity,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(15),
                       image: const DecorationImage(
                         image: NetworkImage('https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=800&q=80'), // Map placeholder
                         fit: BoxFit.cover,
                       ),
                       border: Border.all(color: Colors.grey[800]!),
                     ),
                   ),
                   // Address formatted box below map
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(12),
                     decoration: const BoxDecoration(
                       color: Color(0xFF2C2C2C), // Dark box
                       borderRadius: BorderRadius.only(
                         bottomLeft: Radius.circular(15),
                         bottomRight: Radius.circular(15),
                       ),
                     ),
                     child: const Text( // Arabic Address as plain text for now, right aligned if RTL, but keeping English LTR for structure
                       'مصر - أسوان - مركز شباب الساحة',
                       textAlign: TextAlign.right,
                       style: TextStyle(color: Colors.white, fontSize: 14),
                     ),
                   ),
                   
                   const SizedBox(height: 16),
                   _buildInputLabel('Social media'),
                   _buildTextField(_socialController),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Documents (Read Only)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel('National ID front'),
                   _buildDocumentCard('National ID front', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('National ID back'),
                   _buildDocumentCard('National ID Back', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Tax card'), // Typo from image 'Tex card' corrected to 'Tax card' unless strictly 'Tex' required. Image says 'Tex card' in label, 'Tax card' in box. I will use 'Tax card'.
                   _buildDocumentCard('Tax card', '300 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Commercial register'),
                   _buildDocumentCard('commercial register', '200 KB'),
                ],
              ),
            ),
          ],
        ),
      ),
      // 4. Fixed Confirm Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFF121212),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
               Navigator.pop(context); // Go back on confirm
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), // Darker input bg
        borderRadius: BorderRadius.circular(12), // Pill/Rounded as updated standard
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
         gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                 const Color(0xFF2D5016).withValues(alpha: 0.8), // Dark Green
                 const Color(0xFF1E1E1E), 
              ],
            ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: const BoxDecoration(
               color: Colors.transparent, // Or slight background
             ),
             child: const Icon(Icons.image_outlined, color: Colors.white, size: 24),
           ),
           const SizedBox(width: 12),
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.normal)),
               Text(size, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
               const SizedBox(height: 4),
               GestureDetector(
                 onTap: () {
                   // View logic
                 },
                 child: const Text(
                   'Click to view',
                   style: TextStyle(
                     color: Colors.white,
                     fontSize: 12,
                     fontWeight: FontWeight.bold,
                     decoration: TextDecoration.underline,
                   ),
                 ),
               ),
             ],
           )
        ],
      ),
    );
  }

  // Reuse logic from OwnerStadiumsScreen for visual consistency, simplified for horizontal list
  Widget _buildStadiumCard(Stadium stadium) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(stadium.imageUrl),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: AppTheme.neonGreen, width: 1.5), // Highlight selected or card style
      ),
      child: Stack(
        children: [
          // Top Left: Location Badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: AppTheme.neonGreen, size: 14),
                  const SizedBox(width: 4),
                  Text(stadium.location, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          
          // Top Right: Edit Icon
          Positioned(
            top: 12,
            right: 12,
            child: InkWell(
              onTap: () {
                 // Navigate to Edit Stadium
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit Stadium - Coming Soon')));
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.neonGreen),
                ),
                child: const Icon(Icons.edit_outlined, color: AppTheme.neonGreen, size: 18),
              ),
            ),
          ),

          // Bottom Info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18), // Slightly less than 20 due to border
                  bottomRight: Radius.circular(18),
                ),
                color: Colors.black.withValues(alpha: 0.7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(stadium.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.normal), maxLines: 1),
                   const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(children: [
                         const Icon(Icons.male, color: Colors.white, size: 14),
                         const SizedBox(width: 4),
                         const Icon(Icons.location_on_outlined, color: Colors.white, size: 14),
                       ]),
                       const Text('Cafeteria', style: TextStyle(color: Colors.white, fontSize: 12)),
                       Text('Seats K${(stadium.seatsCapacity/1000).toStringAsFixed(0)} person', style: const TextStyle(color: Colors.white, fontSize: 12)),
                     ],
                   ),
                    const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text('Price ${NumberFormat('#,###').format(stadium.pricePerHour)} eu', style: const TextStyle(color: AppTheme.neonGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(stadium.area, style: const TextStyle(color: Colors.white, fontSize: 12)),
                     ],
                   )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

