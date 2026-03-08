import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../shared/widgets/custom_text_field.dart';
import '../../owner/screens/add_stadium_wizard.dart';
import '../../../core/navigation/root_screen.dart';

class SocialOnboardingScreen extends StatefulWidget {
  const SocialOnboardingScreen({super.key});

  @override
  State<SocialOnboardingScreen> createState() => _SocialOnboardingScreenState();
}

class _SocialOnboardingScreenState extends State<SocialOnboardingScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedPosition = 'GK';
  String _selectedGovernorate = 'Cairo';
  bool _isLoading = false;
  bool _nameInitialized = false;
  
  // Validation state
  String _passwordError = '';
  String _confirmPasswordError = '';
  double _strengthValue = 0.0; // 0.0 to 1.0
  Color _strengthColor = VSPColors.error;
  String _strengthLabel = 'Weak';

  final List<String> _positions = ['GK', 'CB', 'LB', 'RB', 'MID', 'LW', 'RW', 'ST'];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
    _phoneController.addListener(() => setState(() {})); // Re-evaluate form validity

    // Pre-fill name from Google properly in initState to avoid build issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.userModel?.name != null && _nameController.text.isEmpty) {
        setState(() {
          _nameController.text = auth.userModel!.name!;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final value = _passwordController.text;
    setState(() {
      if (value.isEmpty) {
        _passwordError = '';
        _strengthValue = 0.0;
        _strengthLabel = 'Weak';
        _strengthColor = VSPColors.error;
        return;
      }

      // Calculate strength
      if (value.length < 6) {
        _passwordError = 'At least 6 characters required';
        _strengthValue = 0.3;
        _strengthLabel = 'Weak';
        _strengthColor = VSPColors.error;
      } else {
        _passwordError = '';
        bool hasDigits = value.contains(RegExp(r'[0-9]'));
        bool hasSpecial = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
        
        if (value.length >= 8 && hasDigits && hasSpecial) {
          _strengthValue = 1.0;
          _strengthLabel = 'Strong';
          _strengthColor = VSPColors.accent;
        } else {
          _strengthValue = 0.6;
          _strengthLabel = 'Medium';
          _strengthColor = VSPColors.warning;
        }
      }
    });
  }

  void _validateConfirmPassword() {
    setState(() {
      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = '';
      } else if (_confirmPasswordController.text != _passwordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = '';
      }
    });
  }

  bool get _isFormValid {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    
    return phone.length >= 10 && 
           password.length >= 6 && 
           password == confirm &&
           !_isLoading;
  }

  Future<void> _handleCompleteRegistration() async {
    if (!_isFormValid) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.completeSocialRegistration(
      phone: phone,
      password: password,
      name: name,
      position: authProvider.isPlayer ? _selectedPosition : null,
      governorate: _selectedGovernorate,
    );

    if (!mounted) return;

    if (success) {
      // Logic: RootScreen is listening to AuthProvider. 
      // It will see that phone is now filled but isRegistrationComplete is still false, 
      // thus it will automatically show VerifyEmailScreen (OTP). 
      // No manual Navigator call needed here.
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

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [], // Clean
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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

              // Editable Full Name
              _buildLabel('Full Name'),
              CustomTextField(
                controller: _nameController,
                hintText: 'Enter your full name',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
              _buildReadOnlyField('Email Address', auth.userModel?.email ?? ''),
              
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

              const SizedBox(height: 20),
              _buildLabel('Set Password'),
              CustomTextField(
                controller: _passwordController,
                hintText: '********',
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                errorText: _passwordError.isNotEmpty ? _passwordError : null,
              ),
              
              const SizedBox(height: 12),
              // Password Strength Indicator
              if (_passwordController.text.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Strength: $_strengthLabel',
                      style: TextStyle(color: _strengthColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(_strengthValue * 100).toInt()}%',
                      style: TextStyle(color: _strengthColor, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _strengthValue,
                    backgroundColor: VSPColors.divider.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                    minHeight: 4,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _buildLabel('Confirm Password'),
              CustomTextField(
                controller: _confirmPasswordController,
                hintText: '********',
                obscureText: true,
                prefixIcon: Icons.lock_clock_outlined,
                errorText: _confirmPasswordError.isNotEmpty ? _confirmPasswordError : null,
              ),

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

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isFormValid ? _handleCompleteRegistration : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    disabledBackgroundColor: VSPColors.accent.withValues(alpha: 0.3),
                    foregroundColor: VSPColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    elevation: _isFormValid ? 4 : 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: VSPColors.background, strokeWidth: 2),
                        )
                      : Text(
                          isOwner ? 'Continue to Stadium Setup' : 'Complete Registration',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isFormValid ? VSPColors.background : VSPColors.textSecondary.withValues(alpha: 0.24),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
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
    final govs = [
      'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 
      'Luxor', 'Aswan', 'Gharbia', 'Port Said', 'Suez', 
      'Ismailia', 'Minya', 'Assiut'
    ];
    
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

