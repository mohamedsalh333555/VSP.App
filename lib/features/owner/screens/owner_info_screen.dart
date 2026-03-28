import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'owner_main_screen.dart';

class OwnerInfoScreen extends StatefulWidget {
  const OwnerInfoScreen({super.key});

  @override
  State<OwnerInfoScreen> createState() => _OwnerInfoScreenState();
}

class _OwnerInfoScreenState extends State<OwnerInfoScreen> {
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
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
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
    final governorate = _addressController.text.trim();

    if (name.isEmpty) {
      VSPFeedback.showError(context, 'Please enter your full name');
      return;
    }
    if (phone.isEmpty) {
      VSPFeedback.showError(context, 'Please enter your phone number');
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Save to Firestore
    final success = await authProvider.updateProfile({
      'name': name,
      'phone': phone,
      'governorate': governorate.isNotEmpty ? governorate : 'Aswan',
      'additionalData': {
        ...authProvider.userModel?.additionalData ?? {},
        'socialMedia': _socialController.text.trim(),
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _showSuccessDialog(context);
      } else {
        VSPFeedback.showError(context, 'Failed to save information. Please try again.');
      }
    }
  }

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
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
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

            _buildLabel('Full Name'),
            _buildTextField(_nameController, hint: 'Enter your name'),
             const SizedBox(height: 16),
            
            _buildLabel('Phone Number'),
            _buildTextField(_phoneController, hint: 'Enter your phone', keyboardType: TextInputType.phone),
             const SizedBox(height: 16),

            _buildLabel('Email'),
            _buildTextField(_emailController, hint: 'Enter your email', enabled: false),
             const SizedBox(height: 16),

            _buildLabel('Location'),
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
                        if (!context.mounted) return;
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

             _buildLabel('Social Media'),
            _buildTextField(_socialController, hint: 'https://instagram.com/your-account'),

            const SizedBox(height: 40),

            PrimaryButton(
              text: 'Save',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _saveData,
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
                  'Your profile has been updated successfully.',
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

  Widget _buildLabel(String text) {
     return Padding(
       padding: const EdgeInsets.only(bottom: VSPSpacing.xs),
       child: Text(
         text,
         style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
       ),
     );
  }

  Widget _buildTextField(TextEditingController controller, {required String hint, bool enabled = true, TextInputType? keyboardType}) {
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
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
        ),
      ),
    );
  }
}
