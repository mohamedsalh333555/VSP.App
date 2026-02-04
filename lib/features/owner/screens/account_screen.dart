import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';
import 'add_stadium_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Account',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stadiums List (Horizontal)
            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                   _buildStadiumCard(context),
                   const SizedBox(width: 16),
                   // Placeholder for seeing another one
                   Opacity(opacity: 0.5, child: _buildStadiumCard(context)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Owner Info Form
            _buildLabel('Owner Name'),
            _buildTextField(hint: 'Sal acd'),
            const SizedBox(height: 16),

            _buildLabel('Number'),
            _buildTextField(hint: '+20 0111000222'),
            const SizedBox(height: 16),

            _buildLabel('Email'),
            _buildTextField(hint: 'hana.mohamed@gmail.com'),
            const SizedBox(height: 16),

            _buildLabel('Add Address'),
             Container(
              height: 150,
              width: double.infinity,
              child: Stack(
                children: [
                   ShimmerImage(
                    imageUrl: 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=800&q=80',
                    fit: BoxFit.cover,
                    borderRadius: 0,
                  ),
                  const Center(
                    child: Icon(Icons.location_on, size: 40, color: Colors.red),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Egypt - Aswan - Elaha Youth Center',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                   border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.edit_location_alt, color: AppTheme.textSecondary, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Social media'),
            _buildTextField(hint: 'https://www.facebook.com/search/pages/?q=VSP&sde=Abrgg...'),
            const SizedBox(height: 24),

            // Documents
            _buildLabel('National ID front'),
            _buildDocCard('National ID front'),
            const SizedBox(height: 12),

            _buildLabel('National ID back'),
            _buildDocCard('National ID Back'),
            const SizedBox(height: 12),

            _buildLabel('Tex card'), // Sic: Screenshot says "Tex card"
            _buildDocCard('Tax card'),
            const SizedBox(height: 12),

             _buildLabel('Commercial register'),
            _buildDocCard('commercial register'),
            const SizedBox(height: 40),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Changes Saved Successfully')),
                   );
                   Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStadiumCard(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 200,
      child: Stack(
        children: [
            ShimmerImage(
              imageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&q=80',
              width: 320,
              height: 200,
              borderRadius: 16,
            ),
            Container(
              width: 320,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.4),
                border: Border.all(color: AppTheme.neonGreen),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.neonGreen, size: 16),
                  const SizedBox(width: 4),
                  const Text('Madrid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                   // Navigate to AddStadiumScreen in Edit Mode (Logic to be handled)
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStadiumScreen())); 
                },
                child: const Icon(Icons.edit_square, color: AppTheme.neonGreen),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                       Text('Santiago Bernabeoa 11 VS 11 Football', style: TextStyle(color: Colors.white, fontSize: 12)),
                       Text('Seats K90 person', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                         children: const [
                            Text('Baths', style: TextStyle(color: Colors.white, fontSize: 10)),
                             SizedBox(width: 4),
                            Icon(Icons.male, color: Colors.white, size: 12),
                            Icon(Icons.female, color: Colors.white, size: 12),
                         ],
                       ),
                       const Text('Cafeteria', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                   const SizedBox(height: 4),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                       Text('Price 1,000,000 eu', style: TextStyle(color: AppTheme.neonGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                       Text('Jerash', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
     return Padding(
       padding: const EdgeInsets.only(bottom: 8),
       child: Text(
         text,
         style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
       ),
     );
  }

  Widget _buildTextField({required String hint}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDocCard(String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF335500), // Dark Green background for docs
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.neonGreen.withOpacity(0.5)),
      ),
      child: Row(
        children: [
           const Icon(Icons.image_outlined, color: Colors.white),
           const SizedBox(width: 12),
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
               const Text('200 KB', style: TextStyle(color: Colors.white70, fontSize: 10)),
               const Text('Click to view', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontSize: 12, fontWeight: FontWeight.bold)),
             ],
           )
        ],
      ),
    );
  }
}
