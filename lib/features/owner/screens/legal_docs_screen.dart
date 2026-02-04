import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import 'id_verification_screen.dart';

class LegalDocsScreen extends StatelessWidget {
  const LegalDocsScreen({super.key});

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
          'Owner information', // Matching screenshot title
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
            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  width: 30,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == 0 ? AppTheme.neonGreen : Colors.grey[700], // Step 1 of Owner Info
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            const Text(
              'Upload an image',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

             // Main Upload Button
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.neonGreen, 
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.black),
                   const SizedBox(height: 8),
                   const Text('Click to upload', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                   Text('JPG, JPEG, PNG less than 10MB', style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 10)),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildLabel('Tax card'),
            _buildUploadedFile('Tax card', '200 KB'),

            const SizedBox(height: 16),

            _buildLabel('Commercial register'),
             _buildUploadedFile('commercial register', '200 KB'),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IdVerificationScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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

  Widget _buildUploadedFile(String name, String size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neonGreen),
        color: AppTheme.neonGreen.withOpacity(0.1),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text(size, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              const Text('Click to view', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
