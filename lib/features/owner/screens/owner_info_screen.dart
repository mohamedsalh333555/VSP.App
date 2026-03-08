import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/shimmer_image.dart';
import 'owner_main_screen.dart';

class OwnerInfoScreen extends StatelessWidget {
  const OwnerInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Owner information',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Indicators (Step 3/3)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  width: 30,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == 2 ? VSPColors.accent : VSPColors.divider, 
                    borderRadius: BorderRadius.circular(VSPRadius.xs),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            _buildLabel(context, 'Full Name'),
            _buildTextField(context, hint: 'Enter your name'),
             const SizedBox(height: 16),
            
            _buildLabel(context, 'Phone Number'),
            _buildTextField(context, hint: 'Enter your phone'),
             const SizedBox(height: 16),

            _buildLabel(context, 'Email'),
            _buildTextField(context, hint: 'Enter your email'),
             const SizedBox(height: 16),

            _buildLabel(context, 'Add Address'),
            // Map Placeholder
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.md)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                   ShimmerImage(
                    imageUrl: 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=800&q=80',
                    fit: BoxFit.cover,
                    borderRadius: 0,
                  ),
                   const Center(
                    child: Icon(Icons.location_on, size: 40, color: VSPColors.accent), // More consistent than red
                  ),
                ],
              ),
            ),
            // Address Text Input (Immediately below map)
            Container(
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(VSPRadius.md)),
                border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1), width: 0.5),
              ),
              child: TextField(
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Egypt - Aswan - Elaha Youth Center',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
                  prefixIcon: const Icon(Icons.edit_location_alt, color: VSPColors.textSecondary, size: 20),
                ),
              ),
            ),
             const SizedBox(height: 16),

             _buildLabel(context, 'Social Media'),
            _buildTextField(context, hint: 'https://www.facebook.com/search/pages/?q=VSP&sde=...'),

            const SizedBox(height: 40),

            PrimaryButton(
              text: 'Save',
              onPressed: () {
                // Demo Mode Bypass
                if (AppConfig.demoMode) {
                   _showSuccessDialog(context);
                   return;
                }
                
                _showSuccessDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: VSPColors.accent, size: 64),
                const SizedBox(height: VSPSpacing.md),
                Text(
                  'Success!',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: VSPSpacing.xs),
                Text(
                  'Your stadium has been added successfully.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                ),
                const SizedBox(height: VSPSpacing.lg),
                PrimaryButton(
                  text: 'Go to Dashboard',
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const OwnerMainScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
     return Padding(
       padding: const EdgeInsets.only(bottom: VSPSpacing.xs),
       child: Text(
         text,
         style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
       ),
     );
  }

  Widget _buildTextField(BuildContext context, {required String hint}) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1), width: 0.5),
      ),
      child: TextField(
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
        ),
      ),
    );
  }
}
