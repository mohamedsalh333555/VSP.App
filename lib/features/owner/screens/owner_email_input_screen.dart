import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../auth/screens/owner_verify_email_screen.dart';

/// Owner Email Input Screen - Step 1/3
class OwnerEmailInputScreen extends StatefulWidget {
  const OwnerEmailInputScreen({super.key});

  @override
  State<OwnerEmailInputScreen> createState() => _OwnerEmailInputScreenState();
}

class _OwnerEmailInputScreenState extends State<OwnerEmailInputScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    
    if (name.isEmpty || !name.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name (First and Last name)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (phone.isEmpty || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Demo Mode Bypass
    if (AppConfig.demoMode) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.setName(name);
        authProvider.setEmail(email);
        authProvider.setPhone(phone);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OwnerVerifyEmailScreen(email: email),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.setName(name);
    authProvider.setEmail(email);
    authProvider.setPhone(phone);
    // No position needed for owner

    // Simulate verification
    await authProvider.sendVerificationCode();

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerVerifyEmailScreen(email: email),
      ),
    );
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
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Back Button
                IconButton(
                  icon: Icon(
                    languageProvider.isArabic
                        ? Icons.arrow_forward
                        : Icons.arrow_back,
                    color: AppTheme.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(height: 40),

                // Title
                Center(
                  child: Text(
                    languageProvider.isArabic
                        ? 'أضف بريدك الإلكتروني'
                        : 'Add your email',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Progress Indicator
                _ProgressIndicator(currentStep: 1),

                const SizedBox(height: 40),

                // Name Label
                Text(
                  languageProvider.isArabic ? 'الاسم بالكامل' : 'Full Name',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // Name Input
                CustomTextField(
                  controller: _nameController,
                  hintText: languageProvider.isArabic ? 'الاسم الأول والأخير' : 'First and Last Name',
                  keyboardType: TextInputType.name,
                ),

                const SizedBox(height: 24),

                // Email Label
                Text(
                  languageProvider.isArabic ? 'البريد الإلكتروني' : 'Email Address',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // Email Input
                CustomTextField(
                  controller: _emailController,
                  hintText: 'name@business.com',
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 24),

                // Phone Label
                Text(
                  languageProvider.isArabic ? 'رقم الموبايل' : 'Phone Number',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // Phone Input
                CustomTextField(
                  controller: _phoneController,
                  hintText: languageProvider.isArabic ? '0100 000 0000' : 'Phone Number',
                  keyboardType: TextInputType.phone,
                ),

                const Spacer(),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading 
                        ? null 
                        : () {
                            _handleContinue();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonGreen,
                      foregroundColor: AppTheme.darkBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.darkBackground,
                              ),
                            ),
                          )
                        : Text(
                            languageProvider.isArabic
                                ? 'المتابعة'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 40),

                // Terms and Privacy - Simplified
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Bottom Indicator
                Center(
                  child: Container(
                    width: 134,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textPrimary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int currentStep;

  const _ProgressIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStep(1),
        const SizedBox(width: 8),
        _buildStep(2),
        const SizedBox(width: 8),
        _buildStep(3),
      ],
    );
  }

  Widget _buildStep(int step) {
    final isActive = step <= currentStep;
    return Container(
      width: 60,
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.neonGreen : AppTheme.textSecondary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
