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
import '../../../shared/widgets/vsp_date_picker_dialog.dart';

/// Unified Registration Screen - collects name, phone, email, and password.
class SignupScreen extends StatefulWidget {
  final bool isOwner;
  const SignupScreen({super.key, required this.isOwner});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _selectedPosition; // Only for players
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchAutoLocation());
  }

  Future<void> _fetchAutoLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).updateUserLocation(force: true);
    } catch (e) {
      debugPrint('Error auto-fetching location in signup: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showVSPDatePicker(
      context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      minYear: 1940,
      maxYear: DateTime.now().year - 10,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName';
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      VSPFeedback.showError(
        context, 
        AppLocalizations.of(context)!.fillAllFields
      );
      return;
    }
    if (_dateOfBirth == null) {
      VSPFeedback.showError(context, AppLocalizations.of(context)!.pleaseEnterDob);
      return;
    }

    if (!widget.isOwner && _selectedPosition == null) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(context, isAr ? 'يرجى اختيار مركزك المفضل ⚽' : 'Please select your preferred position ⚽');
      return;
    }

    if (phone.length != 11 || !phone.startsWith("01")) {
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
        'name': fullName,
        'phone': phone,
        'position': widget.isOwner ? null : _selectedPosition,
        'date_of_birth': _dateOfBirth?.toUtc().toIso8601String(),
      },
    );

    debugPrint("[DEBUG_SIGNUP] signUp result=$success error=${authProvider.errorMessage}");

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
        String errorMsg = authProvider.errorMessage ?? 'فشل إنشاء الحساب';
        if (errorMsg.contains('confirmation email') || errorMsg.contains('unexpected_failure')) {
          errorMsg = 'تعذر إرسال إيميل التأكيد. يرجى التمرير لأسفل في نافذة Email في Supabase وإيقاف خيار (Confirm email).';
        }
        debugPrint("[DEBUG_SIGNUP] Showing error toast: $errorMsg");
        VSPFeedback.showError(context, errorMsg);
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
                          icon: Localizations.localeOf(context).languageCode == 'ar' ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
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
                  
                  // Fields — First & Last Name
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(AppLocalizations.of(context)!.firstName),
                            CustomTextField(
                              controller: _firstNameController,
                              hintText: AppLocalizations.of(context)!.firstNameHint,
                              textInputAction: TextInputAction.next,
                              prefixIcon: LucideIcons.user,
                              maxLength: 30,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel(AppLocalizations.of(context)!.lastName),
                            CustomTextField(
                              controller: _lastNameController,
                              hintText: AppLocalizations.of(context)!.lastNameHint,
                              textInputAction: TextInputAction.next,
                              prefixIcon: LucideIcons.user2,
                              maxLength: 30,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Date of Birth
                  const SizedBox(height: 16),
                  _buildLabel(AppLocalizations.of(context)!.dateOfBirth),
                  GestureDetector(
                    onTap: _pickDateOfBirth,
                    child: Container(
                      height: VSPSize.inputHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.input),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.calendar, color: VSPColors.textSecondary, size: 18),
                          const SizedBox(width: 12),
                          Text(
                            _dateOfBirth != null
                                ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
                                : AppLocalizations.of(context)!.dateOfBirthPlaceholder,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _dateOfBirth != null ? VSPColors.textPrimary : VSPColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (_dateOfBirth != null)
                            Icon(LucideIcons.checkCircle, color: VSPColors.accent, size: 16),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(widget.isOwner ? AppLocalizations.of(context)!.addPersonalPhoneNumber : AppLocalizations.of(context)!.phoneNumber),
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
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.governorate,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (_isFetchingLocation)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                        )
                      else
                        GestureDetector(
                          onTap: _fetchAutoLocation,
                          child: const Icon(LucideIcons.locate, color: VSPColors.accent, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                    textInputAction: TextInputAction.next,
                    prefixIcon: LucideIcons.mail,
                  ),
                  
                  const SizedBox(height: 16),
                  _buildLabel(AppLocalizations.of(context)!.password),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: '********',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
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
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _handleSignup();
                    },
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final positions = [
      {'code': 'GK', 'label': isAr ? 'حارس' : 'GK'},
      {'code': 'DF', 'label': isAr ? 'مدافع' : 'DF'},
      {'code': 'MF', 'label': isAr ? 'خط وسط' : 'MF'},
      {'code': 'FW', 'label': isAr ? 'مهاجم' : 'FW'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(AppLocalizations.of(context)!.preferredPosition),
        const SizedBox(height: 4),
        Row(
          children: positions.map((pos) {
            final code = pos['code'] as String;
            final label = pos['label'] as String;
            final isSelected = _selectedPosition == code;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPosition = code);
                      },
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? VSPColors.accent.withValues(alpha: 0.15)
                              : VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(
                            color: isSelected ? VSPColors.accent : VSPColors.borderLight,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: VSPColors.accent.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
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
    final auth = Provider.of<AuthProvider>(context);
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
