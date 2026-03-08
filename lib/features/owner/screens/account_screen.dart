import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/widgets/shimmer_image.dart';
import 'add_stadium_wizard.dart';
import '../../../core/utils/vsp_feedback.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
          'Account',
          style: Theme.of(context).textTheme.displaySmall,
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
            _buildLabel(context, 'Owner Name'),
            _buildTextField(context, hint: 'Sal acd'),
            const SizedBox(height: 16),

            _buildLabel(context, 'Number'),
            _buildTextField(context, hint: '+20 0111000222'),
            const SizedBox(height: 16),

            _buildLabel(context, 'Email'),
            _buildTextField(context, hint: 'hana.mohamed@gmail.com'),
            const SizedBox(height: 16),

            _buildLabel(context, 'Add Address'),
             Container(
              height: 150,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(VSPRadius.md),
                  topRight: Radius.circular(VSPRadius.md),
                ),
              ),
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
            ),
            Container(
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(VSPRadius.md),
                  bottomRight: Radius.circular(VSPRadius.md),
                ),
              ),
              child: TextField(
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Egypt - Aswan - Elaha Youth Center',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                   border: InputBorder.none,
                   contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
                  prefixIcon: const Icon(Icons.edit_location_alt, color: VSPColors.textSecondary, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel(context, 'Social media'),
            _buildTextField(context, hint: 'https://www.facebook.com/search/pages/?q=VSP&sde=Abrgg...'),
            const SizedBox(height: 24),

            // Documents
            _buildLabel(context, 'National ID front'),
            _buildDocCard(context, 'National ID front'),
            const SizedBox(height: 12),

            _buildLabel(context, 'National ID back'),
            _buildDocCard(context, 'National ID Back'),
            const SizedBox(height: 12),

            _buildLabel(context, 'Tex card'), // Sic: Screenshot says "Tex card"
            _buildDocCard(context, 'Tax card'),
            const SizedBox(height: 12),

             _buildLabel(context, 'Commercial register'),
            _buildDocCard(context, 'commercial register'),
            const SizedBox(height: 40),

            PrimaryButton(
              text: 'Confirm',
              onPressed: () {
                 VSPFeedback.showSuccess(context, 'Changes Saved Successfully');
                 Navigator.pop(context);
              },
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
            VSPCard(
              width: 320,
              height: 200,
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderRadius: VSPRadius.lg,
              border: Border.all(color: VSPColors.accent),
              child: Stack(
                children: [
                    ShimmerImage(
                      imageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&q=80',
                      width: 320,
                      height: 200,
                      borderRadius: VSPRadius.lg,
                    ),
                    Container(
                      width: 320,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                      ),
                    ),
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: VSPColors.accent, size: 16),
                  const SizedBox(width: 4),
                  Text('Madrid', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                   // Navigate to AddStadiumWizard in Edit Mode
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStadiumWizard())); 
                },
                child: const Icon(Icons.edit_square, color: VSPColors.accent),
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
                          children: [
                            Text('Santiago Bernabeoa 11 VS 11 Football', style: Theme.of(context).textTheme.bodySmall),
                            Text('Seats K90 person', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('Baths', style: Theme.of(context).textTheme.labelSmall),
                                const SizedBox(width: 4),
                                Icon(Icons.male, color: VSPColors.textPrimary, size: 12),
                                Icon(Icons.female, color: VSPColors.textPrimary, size: 12),
                              ],
                            ),
                            Text('Cafeteria', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Price 1,000,000 eu', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: VSPColors.accent)),
                            Text('Jerash', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, String name) {
    return VSPCard(
      padding: const EdgeInsets.all(VSPSpacing.md),
      color: VSPColors.accent.withValues(alpha: 0.05),
      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
      child: Row(
        children: [
           const Icon(Icons.image_outlined, color: VSPColors.textPrimary),
           const SizedBox(width: VSPSpacing.md),
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(name, style: Theme.of(context).textTheme.titleSmall),
               Text('200 KB', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
               Text('Click to view', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, decoration: TextDecoration.underline)),
             ],
           )
        ],
      ),
    );
  }
}

