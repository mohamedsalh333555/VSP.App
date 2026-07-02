import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/constants/egypt_governorates.dart';


class SocialOnboardingScreen extends StatefulWidget {
  const SocialOnboardingScreen({super.key});

  @override
  State<SocialOnboardingScreen> createState() => _SocialOnboardingScreenState();
}

class _SocialOnboardingScreenState extends State<SocialOnboardingScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedPosition = 'GK';
  String _selectedGovernorate = 'Cairo';
  bool _isLoading = false;
  final bool _nameInitialized = false;

  final List<String> _positions = ['GK', 'CB', 'LB', 'RB', 'MID', 'LW', 'RW', 'ST'];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {})); // Re-evaluate form validity

    // Pre-fill name from Google/Social provider properly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      // If we have a userModel, use its name. 
      // If we are a Ghost User, fallback to Firebase's displayName.
      final displayName = auth.userModel?.name ?? auth.currentUser?.userMetadata?['name'] as String?;
      
      if (displayName != null && displayName.isNotEmpty && _nameController.text.isEmpty) {
        setState(() {
          _nameController.text = displayName;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }



  bool get _isFormValid {
    final phone = _phoneController.text.trim();
    return phone.length >= 10 && !_isLoading;
  }

  Future<void> _handleCompleteRegistration() async {
    if (!_isFormValid) return;

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.completeSocialRegistration(
      phone: phone,
      name: name,
      position: authProvider.isPlayer ? _selectedPosition : null,
      governorate: _selectedGovernorate,
    );

    if (!mounted) return;

    if (success) {
      // Mark registration complete — GoRouter will automatically route to
      // /player or /owner via its redirect function once notifyListeners fires.
      if (authProvider.firebaseUser != null) {
        await authProvider.verifyEmailManual(authProvider.firebaseUser!.uid);
      }
      await authProvider.updateProfile({
        'isRegistrationComplete': true,
        'isEmailVerified': true,
      });
      // ✅ No imperative navigation needed — GoRouter handles it.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Registration failed')),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isOwner = auth.isOwner;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await auth.signOut();
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
            onPressed: () => auth.signOut(),
          ),
          actions: const [],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 16.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Just a few more details to get you started',
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 32),

                _buildLabel('Full Name'),
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Enter your full name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 20),
                _buildReadOnlyField('Email Address', auth.userModel?.email ?? auth.currentUser?.email ?? 'N/A'),
                
                const SizedBox(height: 20),
                _buildLabel('Phone Number'),
                CustomTextField(
                  controller: _phoneController,
                  hintText: '01xxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),

                const SizedBox(height: 20),
                _buildLabel('Governorate'),
                _buildGovernorateDropdown(),


                if (!isOwner) ...[
                  const SizedBox(height: 20),
                  _buildLabel('Preferred Position'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPosition,
                        dropdownColor: VSPColors.surface,
                        icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary),
                        isExpanded: true,
                        style: Theme.of(context).textTheme.bodyMedium,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedPosition = newValue;
                            });
                          }
                        },
                        items: _positions.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: VSPColors.background,
            border: Border(top: BorderSide(color: VSPColors.divider.withValues(alpha: 0.1))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: PrimaryButton(
              text: AppConfig.bypassOtp 
                ? 'Complete & Verify (Bypass)' 
                : (isOwner ? 'Continue to Stadium Setup' : 'Complete Registration'),
              isLoading: _isLoading,
              onPressed: _isFormValid ? _handleCompleteRegistration : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: VSPColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.divider),
          ),
          child: Text(
            value.isEmpty ? 'N/A' : value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildGovernorateDropdown() {
    final govs = EgyptGovernorates.allGovernorates;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGovernorate,
          dropdownColor: VSPColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedGovernorate = newValue;
              });
            }
          },
          items: govs.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}

