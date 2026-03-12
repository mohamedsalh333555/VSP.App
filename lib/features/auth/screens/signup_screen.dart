import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import 'verify_email_screen.dart';
import '../../../core/utils/vsp_feedback.dart';

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
      VSPFeedback.showError(
        context, 
        Provider.of<LanguageProvider>(context, listen: false).isArabic 
            ? 'يرجى ملء جميع الحقول' 
            : 'Please fill all fields'
      );
      return;
    }

    if (password != confirmPassword) {
      VSPFeedback.showError(
        context, 
        Provider.of<LanguageProvider>(context, listen: false).isArabic 
            ? 'كلمات المرور غير متطابقة' 
            : 'Passwords do not match'
      );
      return;
    }

    if (password.length < 6) {
      VSPFeedback.showError(
        context, 
        Provider.of<LanguageProvider>(context, listen: false).isArabic 
            ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' 
            : 'Password must be at least 6 characters'
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
      if (mounted) {
        VSPFeedback.showError(context, authProvider.errorMessage ?? 'فشل إنشاء الحساب');
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: VSPColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: VSPColors.background,
        body: Stack(
          children: [
            // 1. Subtle Background Elements
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accent.withValues(alpha: 0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24.0, 
                  right: 24.0, 
                  top: 0, 
                  bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    
                    // Header Nav
                    Row(
                      children: [
                        _buildNavCircle(
                          context, 
                          icon: languageProvider.isArabic ? Icons.arrow_forward : Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Image.asset(
                          'assets/images/logo.png',
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Text(
                      languageProvider.isArabic ? 'إنشاء حساب جديد' : 'Create Account',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 38,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isOwner 
                        ? (languageProvider.isArabic ? 'سجل كصاحب ملعب لتفعيل نظام حجوزاتك' : 'Register as owner and manage your pitch')
                        : (languageProvider.isArabic ? 'سجل كلاعب وشارك في أقوى التحديات' : 'Register as player and start your journey'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Progress or Form Title
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: VSPColors.accent,
                            borderRadius: BorderRadius.circular(VSPRadius.xs),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Personal Information',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            letterSpacing: 1.1,
                            color: VSPColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  
                  // Fields
                  _buildLabel(languageProvider.isArabic ? 'الاسم الكامل' : 'Full Name'),
                  CustomTextField(
                    controller: _nameController,
                    hintText: languageProvider.isArabic ? 'أدخل اسمك' : 'Enter your name',
                    prefixIcon: Icons.person_outline,
                    maxLength: 50,
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(languageProvider.isArabic ? 'رقم الهاتف' : 'Phone Number'),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: '01xxxxxxxxx',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    maxLength: 15,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: VSPColors.textSecondary),
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
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: VSPColors.textSecondary),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.accent.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: VSPColors.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                          elevation: 0, 
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: VSPColors.background, strokeWidth: 3),
                            )
                          : Text(
                              languageProvider.isArabic ? 'إنشاء الحساب' : 'Create Account',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCircle(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, color: VSPColors.textPrimary, size: 20),
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
                  selectedColor: VSPColors.accent,
                  backgroundColor: VSPColors.surface,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    side: BorderSide(
                      color: isSelected ? VSPColors.accent : VSPColors.divider.withValues(alpha: 0.05),
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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
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
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: auth.governorate.isEmpty ? 'Cairo' : auth.governorate,
          dropdownColor: VSPColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
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
