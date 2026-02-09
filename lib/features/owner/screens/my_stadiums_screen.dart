import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';
import 'add_stadium_screen.dart';

class MyStadiumsScreen extends StatelessWidget {
  const MyStadiumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock empty state for onboarding flow
    const bool hasStadiums = false; 

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () {}, // Handle back if needed or hide
        ),
        title: const Text(
          'Stadiums',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildEmptyState(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'All your stadiums will appear here.',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add your stadium now',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 40),
        
        // Placeholder for Isometric Stadium Image
        // In reality, this would be an asset image. 
        // Using a container with gradient/icon for now to simulate the visual weight.
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: ShimmerImage(
              imageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&q=80',
              fit: BoxFit.contain,
              borderRadius: 20,
              errorWidget: const Icon(Icons.stadium, size: 100, color: Colors.grey),
            ),
          ),
        ),
        
        const SizedBox(height: 40),

        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddStadiumScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF335500), // Dark Green/Olive as per design
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Add stadium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
