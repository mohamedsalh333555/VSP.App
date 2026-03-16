import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/custom_text_field.dart';
import 'success_modal.dart';

/// Set Password Screen - Step 3/3
class SetPasswordNewScreen extends StatefulWidget {
  const SetPasswordNewScreen({super.key});

  @override
  State<SetPasswordNewScreen> createState() => _SetPasswordNewScreenState();
}

class _SetPasswordNewScreenState extends State<SetPasswordNewScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Password requirements
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordRequirements);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordRequirements);
    _passwordController.dispose();
    super.dispose();
  }

  void _checkPasswordRequirements() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid => _hasMinLength && _hasNumber && _hasSymbol;

  Future<void> _handleContinue() async {
    // Demo Mode Bypass
    if (AppConfig.demoMode) {
      if (mounted) {
        showSuccessModal(context);
      }
      return;
    }

    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please meet all password requirements'),
          backgroundColor: VSPColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.setPassword(_passwordController.text);

    // Simulate account creation
    final success = await authProvider.createAccount();

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Show success modal
      showSuccessModal(context);
    } else if (mounted) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Account creation failed'),
          backgroundColor: VSPColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: VSPColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: VSPColors.background,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Back Button
                  IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: VSPColors.textPrimary,
                      ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Center(
                    child: Text(
                      'Set Your Password',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Indicator
                  _ProgressIndicator(currentStep: 3),

                  const SizedBox(height: 40),

                  // Password Label
                  Text(
                    'Password',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Password Input
                  CustomTextField(
                    controller: _passwordController,
                    hintText: '******************',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: VSPColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Password Requirements
                  _PasswordRequirement(
                    text: 'Must be at least 8 characters',
                    isMet: _hasMinLength,
                  ),
                  const SizedBox(height: 12),
                  _PasswordRequirement(
                    text: 'Must contain at least 1 number',
                    isMet: _hasNumber,
                  ),
                  const SizedBox(height: 12),
                  _PasswordRequirement(
                    text: 'Must contain at least 1 symbol',
                    isMet: _hasSymbol,
                  ),

                  const SizedBox(height: 40),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isLoading || (!_isPasswordValid && !AppConfig.demoMode))
                          ? null
                          : () {
                              _handleContinue();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isPasswordValid || AppConfig.demoMode)
                            ? VSPColors.accent
                            : VSPColors.textSecondary.withValues(alpha: 0.3),
                        foregroundColor: VSPColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.md),
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
                                VSPColors.background,
                              ),
                            ),
                            )
                          : Text(
                              'Continue',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Terms and Privacy
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VSPColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                              text: 'By using VSP , you agree to the\nTerms and '),
                          TextSpan(
                            text: 'Privacy Policy.',
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Bottom Indicator
                  Center(
                    child: Container(
                      width: 134,
                      height: 5,
                      decoration: BoxDecoration(
                        color: VSPColors.divider,
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// عنصر متطلبات كلمة المرور
class _PasswordRequirement extends StatelessWidget {
  final String text;
  final bool isMet;

  const _PasswordRequirement({
    required this.text,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMet ? VSPColors.accent : Colors.transparent,
            border: Border.all(
              color: isMet ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: isMet
              ? const Icon(
                  Icons.check,
                  size: 16,
                  color: VSPColors.background,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isMet ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.6),
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// مؤشر التقدم
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
        color: isActive ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(VSPRadius.xs),
      ),
    );
  }
}

