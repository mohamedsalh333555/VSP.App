import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

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
        AppLocalizations.of(context)!.fillAllFields
      );
      return;
    }

    if (phone.length < 10) {
      VSPFeedback.showError(
        context, 
        AppLocalizations.of(context)!.invalidPhone
      );
      return;
    }

    if (password != confirmPassword) {
      VSPFeedback.showError(
        context, 
        AppLocalizations.of(context)!.passwordMismatch
      );
      return;
    }

    if (password.length < 6) {
      VSPFeedback.showError(
        context, 
        AppLocalizations.of(context)!.passwordTooShort
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
      final isAlreadyComplete = authProvider.userModel?.isRegistrationComplete == true &&
          (authProvider.userModel?.phone?.isNotEmpty == true);

      if (!isAlreadyComplete) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_verification_email', email);

        if (AppConfig.bypassOtp) {
          // New user — set registration flags so GoRouter routes them home.
          if (authProvider.firebaseUser != null) {
            await authProvider.verifyEmailManual(authProvider.firebaseUser!.uid);
          }
          await authProvider.updateProfile({
            'isRegistrationComplete': true,
            'isEmailVerified': true,
          });
        } else {
          // Go to verify email screen
          if (mounted) {
            context.push('/verify-email', extra: email);
          }
        }
      }
    } else {
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
        statusBarColor: VSPColors.background.withValues(alpha: 0),
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accentGlow,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(color: VSPColors.background.withValues(alpha: 0)),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: VSPSpacing.lg, 
                  right: VSPSpacing.lg, 
                  top: 0, 
                  bottom: MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + VSPSpacing.lg,
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
                          icon: languageProvider.isArabic ? LucideIcons.arrowRight : LucideIcons.arrowLeft,
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
                      AppLocalizations.of(context)!.createNewAccount,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 38,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isOwner 
                        ? AppLocalizations.of(context)!.registerOwnerSubtitle
                        : AppLocalizations.of(context)!.registerPlayerSubtitle,
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
                          AppLocalizations.of(context)!.personalInformation,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            letterSpacing: 1.1,
                            color: VSPColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  
                  // Fields
                  _buildLabel(AppLocalizations.of(context)!.fullName),
                  CustomTextField(
                    controller: _nameController,
                    hintText: AppLocalizations.of(context)!.enterName,
                    prefixIcon: LucideIcons.user,
                    maxLength: 50,
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(AppLocalizations.of(context)!.phoneNumber),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: '01xxxxxxxxx',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    prefixIcon: LucideIcons.phone,
                    maxLength: 15,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),

                  const SizedBox(height: 16),
                  _buildLabel(AppLocalizations.of(context)!.governorate),
                  _buildGovernorateDropdown(languageProvider),

                  // Position Selector (Players Only)
                  if (!widget.isOwner) ...[
                    const SizedBox(height: 16),
                    _buildPositionSelector(languageProvider),
                  ],
                  
                  const SizedBox(height: 16),
                  _buildLabel(AppLocalizations.of(context)!.emailAddress),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'example@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: LucideIcons.mail,
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(AppLocalizations.of(context)!.password),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: '********',
                    obscureText: _obscurePassword,
                    prefixIcon: LucideIcons.lock,
                    onChanged: (val) => setState(() {}),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye, color: VSPColors.textSecondary),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildPasswordStrengthBar(),
                  ],
                  
                  const SizedBox(height: 16),
                  _buildLabel(AppLocalizations.of(context)!.confirmPassword),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: '********',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: LucideIcons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye, color: VSPColors.textSecondary),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  PrimaryButton(
                    text: AppConfig.bypassOtp 
                      ? 'Sign Up & Verify (Bypass)' 
                      : AppLocalizations.of(context)!.createAccount,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _handleSignup,
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
          border: Border.all(color: VSPColors.borderLight),
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
        _buildLabel(AppLocalizations.of(context)!.preferredPosition),
        SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      color: isSelected ? VSPColors.accent : VSPColors.borderLight,
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

  Widget _buildPasswordStrengthBar() {
    final password = _passwordController.text;
    double strength = 0;
    
    if (password.length >= 6) strength += 0.2;
    if (password.length >= 8) strength += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) strength += 0.2;

    Color color = Colors.red;
    String text = 'Weak';
    if (strength > 0.4) { color = Colors.orange; text = 'Medium'; }
    if (strength >= 0.8) { color = VSPColors.accent; text = 'Strong'; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('${(strength * 100).toInt()}%', style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength,
          backgroundColor: VSPColors.surfaceAlt,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(VSPRadius.xs),
          minHeight: 4,
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
    final govs = EgyptGovernorates.allGovernorates;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: auth.governorate.isEmpty ? 'Cairo' : auth.governorate,
          dropdownColor: VSPColors.surface,
          icon: Icon(LucideIcons.chevronDown, color: VSPColors.textSecondary),
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
