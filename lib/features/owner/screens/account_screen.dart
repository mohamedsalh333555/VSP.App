import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/widgets/shimmer_image.dart';
import 'add_stadium_wizard.dart';
import '../../../core/utils/vsp_feedback.dart';

import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../data/models.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _socialController;
  bool _isLoading = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _addressController = TextEditingController(text: user?.governorate ?? '');
    _socialController = TextEditingController(text: user?.additionalData?['socialMedia'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      VSPFeedback.showError(context, 'Name cannot be empty');
      return;
    }
    if (phone.isEmpty) {
      VSPFeedback.showError(context, 'Phone number cannot be empty');
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.updateProfile({
      'name': name,
      'phone': phone,
      'governorate': _addressController.text.trim(),
      'additionalData': {
        ...authProvider.userModel?.additionalData ?? {},
        'socialMedia': _socialController.text.trim(),
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        VSPFeedback.showSuccess(context, 'Changes Saved Successfully');
        Navigator.pop(context);
      } else {
        VSPFeedback.showError(context, 'Failed to save changes');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final stadiums = stadiumProvider.stadiums;

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
              child: stadiums.isEmpty
                ? const Center(child: Text('No stadiums added yet'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: stadiums.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _buildStadiumCard(context, stadiums[index]),
                    ),
                  ),
            ),
            const SizedBox(height: 24),

            // Owner Info Form
            _buildLabel(context, 'Owner Name'),
            _buildTextField(context, controller: _nameController, hint: 'Enter your name'),
            const SizedBox(height: 16),

            _buildLabel(context, 'Number'),
            _buildTextField(context, controller: _phoneController, hint: 'Enter your phone', keyboardType: TextInputType.phone),
            const SizedBox(height: 16),

            _buildLabel(context, 'Email'),
            _buildTextField(context, controller: _emailController, hint: 'Enter your email', enabled: false),
            const SizedBox(height: 16),

            _buildLabel(context, 'Location'),
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: VSPColors.accent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Governorate',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                        ),
                        Text(
                          _addressController.text.isEmpty ? 'Not set' : _addressController.text,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  _isLocating 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent))
                  : IconButton(
                    icon: const Icon(Icons.my_location, color: VSPColors.accent),
                    onPressed: () async {
                      setState(() => _isLocating = true);
                      await Provider.of<AuthProvider>(context, listen: false).updateUserLocation();
                      if (mounted) {
                        setState(() {
                          _addressController.text = Provider.of<AuthProvider>(context, listen: false).governorate;
                          _isLocating = false;
                        });
                        VSPFeedback.showSuccess(context, 'Location updated!');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel(context, 'Social media'),
            _buildTextField(context, controller: _socialController, hint: 'Enter social media link'),
            const SizedBox(height: 24),

            // Documents
            _buildLabel(context, 'National ID front'),
            _buildDocCard(context, 'National ID front'),
            const SizedBox(height: 12),

            _buildLabel(context, 'National ID back'),
            _buildDocCard(context, 'National ID Back'),
            const SizedBox(height: 12),

            _buildLabel(context, 'Tax card'),
            _buildDocCard(context, 'Tax card'),
            const SizedBox(height: 12),

             _buildLabel(context, 'Commercial register'),
            _buildDocCard(context, 'commercial register'),
            const SizedBox(height: 40),

            PrimaryButton(
              text: 'Confirm',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _saveData,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStadiumCard(BuildContext context, Stadium stadium) {
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
                      imageUrl: stadium.imageUrl,
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
                  Text(stadium.location, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
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
                            Expanded(child: Text(stadium.name, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('Seats ${stadium.seatsCapacity} person', style: Theme.of(context).textTheme.labelSmall),
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
                                const Icon(Icons.male, color: VSPColors.textPrimary, size: 12),
                                const Icon(Icons.female, color: VSPColors.textPrimary, size: 12),
                              ],
                            ),
                            Text(stadium.cafeteria > 0 ? 'Cafeteria' : 'No Cafeteria', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Price ${stadium.pricePerHour} EGP', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: VSPColors.accent)),
                            Text(stadium.area, style: Theme.of(context).textTheme.labelSmall),
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

  Widget _buildTextField(BuildContext context, {required TextEditingController controller, required String hint, bool enabled = true, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1), width: 0.5),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: enabled ? VSPColors.textPrimary : VSPColors.textSecondary,
        ),
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

