import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_text_field.dart';
import 'verify_email_screen.dart';

/// Unified Registration Screen - collects name, phone, email, and password.
class SignupScreen extends StatefulWidget {
  final bool isOwner;
  const SignupScreen({super.key, required this.isOwner});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedPosition = 'GK'; // Only for players
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).isArabic 
            ? 'يرجى ملء جميع الحقول' 
            : 'Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).isArabic 
            ? 'كلمات المرور غير متطابقة' 
            : 'Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).isArabic 
            ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' 
            : 'Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Store email in provider for display purposes in verification screen
    authProvider.setEmail(email);

    final role = widget.isOwner ? 'owner' : 'player';
    
    final success = await authProvider.signUp(
      email: email,
      password: password,
      role: role,
      userData: {
        'name': name,
        'phone': phone,
        'position': widget.isOwner ? null : _selectedPosition,
      },
    );

    if (!mounted) return;

    if (success) {
      // Navigate directly to OTP screen - no email verification needed
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
      );
    } else {
      // Failed to sign up
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'فشل إنشاء الحساب'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12), // Reduced top spacing
                  IconButton(
                    icon: Icon(
                      languageProvider.isArabic ? Icons.arrow_forward : Icons.arrow_back,
                      color: AppTheme.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 16), // Reduced spacing
                  // App Logo
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 60, // Reduced logo height
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    languageProvider.isArabic ? 'إنشاء حساب جديد' : 'Create New Account',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isOwner 
                      ? (languageProvider.isArabic ? 'سجل كصاحب ملعب' : 'Register as Owner')
                      : (languageProvider.isArabic ? 'سجل كلاعب' : 'Register as Player'),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 24), // Tighter section spacing
                  
                  // Fields
                  _buildLabel(languageProvider.isArabic ? 'الاسم الكامل' : 'Full Name'),
                  CustomTextField(
                    controller: _nameController,
                    hintText: languageProvider.isArabic ? 'أدخل اسمك' : 'Enter your name',
                    prefixIcon: Icons.person_outline,
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(languageProvider.isArabic ? 'رقم الهاتف' : 'Phone Number'),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: '01xxxxxxxxx',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                  ),

                  const SizedBox(height: 16),
                  _buildLabel(languageProvider.isArabic ? 'المحافظة' : 'Governorate'),
                  _buildGovernorateDropdown(languageProvider),

                  // Position Selector (Players Only)
                  if (!widget.isOwner) ...[
                    const SizedBox(height: 16),
                    _buildPositionSelector(languageProvider),
                  ],
                  
                  const SizedBox(height: 16),
                  _buildLabel(languageProvider.isArabic ? 'البريد الإلكتروني' : 'Email Address'),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'example@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(languageProvider.isArabic ? 'كلمة المرور' : 'Password'),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: '********',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(languageProvider.isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password'),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: '********',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: Icons.lock_clock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonGreen.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonGreen,
                          foregroundColor: AppTheme.darkBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0, // Elevation is handled by the Container boxshadow
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: AppTheme.darkBackground, strokeWidth: 3),
                            )
                          : Text(
                              languageProvider.isArabic ? 'إنشاء الحساب' : 'Create Account',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSelector(LanguageProvider languageProvider) {
    final positions = ['GK', 'CB', 'RB', 'LB', 'CDM', 'CM', 'CAM', 'RW', 'LW', 'ST'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(languageProvider.isArabic ? 'المركز المفضل' : 'Preferred Position'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: positions.map((pos) {
              final isSelected = _selectedPosition == pos;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(pos),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPosition = pos);
                  },
                  selectedColor: AppTheme.neonGreen,
                  backgroundColor: AppTheme.cardBackground,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.neonGreen : Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
              );
            }).toList(),
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
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildGovernorateDropdown(LanguageProvider lang) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final govs = [
      'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 
      'Luxor', 'Aswan', 'Gharbia', 'Port Said', 'Suez', 
      'Ismailia', 'Minya', 'Assiut'
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: auth.governorate.isEmpty ? 'Cairo' : auth.governorate,
          dropdownColor: AppTheme.cardBackground,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
          isExpanded: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          onChanged: (String? newValue) {
            if (newValue != null) {
              auth.setGovernorate(newValue);
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
