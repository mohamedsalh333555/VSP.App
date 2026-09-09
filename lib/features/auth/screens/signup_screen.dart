import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_auth_header.dart';
import '../../../shared/widgets/vsp_date_picker_dialog.dart';
import '../../../shared/widgets/vsp_position_selector.dart';
import '../../../shared/widgets/vsp_terms_checkbox.dart';
import '../services/signup_validation_service.dart';
import '../widgets/signup/signup_date_of_birth_field.dart';
import '../widgets/signup/signup_name_fields.dart';
import '../widgets/signup/signup_password_strength_bar.dart';
import '../widgets/signup_governorate_dropdown.dart';

/// Unified Registration Screen - collects name, phone, email, and password.
class SignupScreen extends StatefulWidget {
 final bool isOwner;
 const SignupScreen({super.key, required this.isOwner});

 @override
 State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _agreedToTerms = false;

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
 if (!mounted) return;
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
    final l10n = AppLocalizations.of(context)!;
    final validation = SignupValidationService.validateForm(
      agreedToTerms: _agreedToTerms,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      rawPhone: _phoneController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      dateOfBirth: _dateOfBirth,
    );

    if (!validation.isValid) {
      VSPFeedback.showError(context, SignupValidationService.getLocalizedErrorMessage(validation.error!, l10n));
      return;
    }

    if (_isLoading) return;

    final fullName = validation.fullName!;
    final normalizedPhone = validation.normalizedPhone!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    // Pre-check phone uniqueness to give instant, friendly feedback
    try {
      final existingPhoneUser = await UserRepository().getUserByPhone(normalizedPhone);
      if (existingPhoneUser != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(
            context,
            isAr ? 'رقم الهاتف مسجل مسبقاً بحساب آخر ' : 'This phone number is already registered to another account ',
          );
        }
        return;
      }
    } catch (_) {
      // Continue to signUp if network pre-check fails
    }

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.setEmail(email);

    final role = widget.isOwner ? 'owner' : 'player';
    final userData = SignupValidationService.buildUserDataPayload(
      fullName: fullName,
      normalizedPhone: normalizedPhone,
      isOwner: widget.isOwner,
      selectedPosition: _selectedPosition,
      dateOfBirth: _dateOfBirth,
    );

    final success = await authProvider.signUp(
      email: email,
      password: password,
      role: role,
      userData: userData,
    );

    debugPrint("[DEBUG_SIGNUP] signUp result=$success error=${authProvider.errorMessage}");

    if (!mounted) return;

    if (success) {
      await SecureStorageService.writeSecure('pending_verification_email', email);
    } else if (mounted) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final errorMsg = SignupValidationService.formatSignupError(authProvider.errorMessage, isArabic: isAr);
      debugPrint("[DEBUG_SIGNUP] Showing error toast: $errorMsg");
      VSPFeedback.showError(context, errorMsg);
    }

    if (mounted) setState(() => _isLoading = false);
  }

 @override
 Widget build(BuildContext context) {
 return AnnotatedRegion<SystemUiOverlayStyle>(
 value: SystemUiOverlayStyle(
 statusBarColor: VSPColors.background.withValues(alpha: 0),
 statusBarIconBrightness: Brightness.light,
 systemNavigationBarColor: VSPColors.background,
 systemNavigationBarIconBrightness: Brightness.light,
 ),
 child: Scaffold(
 backgroundColor: VSPColors.background,
 body: GestureDetector(
 onTap: () => FocusScope.of(context).unfocus(),
 behavior: HitTestBehavior.opaque,
 child: Stack(
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
              const VSPAuthHeader(showLogo: true),

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
              SignupNameFields(
                firstNameController: _firstNameController,
                lastNameController: _lastNameController,
              ),

              // Date of Birth
              const SizedBox(height: 16),
              SignupDateOfBirthField(
                dateOfBirth: _dateOfBirth,
                onTap: _pickDateOfBirth,
              ),
 
 const SizedBox(height: 16),
 _buildLabel(widget.isOwner ? AppLocalizations.of(context)!.addPersonalPhoneNumber : AppLocalizations.of(context)!.phoneNumber),
 CustomTextField(
 controller: _phoneController,
 hintText: '01xxxxxxxxx',
 keyboardType: TextInputType.phone,
 textInputAction: TextInputAction.next,
 prefixIcon: Iconsax.call_copy,
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
 child: const Icon(Iconsax.gps_copy, color: VSPColors.accent, size: 18),
 ),
 ],
 ),
  const SizedBox(height: 8),
  const SignupGovernorateDropdown(),

  // Position Selector (Players Only)
  if (!widget.isOwner) ...[
    const SizedBox(height: 16),
    _buildLabel(AppLocalizations.of(context)!.preferredPosition),
    const SizedBox(height: 4),
    VSPPositionSelector(
      selectedPosition: _selectedPosition,
      onPositionSelected: (code) => setState(() => _selectedPosition = code),
    ),
  ],
 
 const SizedBox(height: 16),
 _buildLabel(AppLocalizations.of(context)!.emailAddress),
 CustomTextField(
 controller: _emailController,
 hintText: 'example@email.com',
 keyboardType: TextInputType.emailAddress,
 textInputAction: TextInputAction.next,
 prefixIcon: Iconsax.sms_copy,
 ),
 
 const SizedBox(height: 16),
 _buildLabel(AppLocalizations.of(context)!.password),
 CustomTextField(
 controller: _passwordController,
 hintText: '********',
 obscureText: _obscurePassword,
 textInputAction: TextInputAction.next,
 prefixIcon: Iconsax.lock_copy,
 onChanged: (val) => setState(() {}),
 suffixIcon: IconButton(
 icon: Icon(_obscurePassword ? Iconsax.eye_slash_copy : Iconsax.eye_copy, color: VSPColors.textSecondary),
 onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
 ),
 ),
 
 if (_passwordController.text.isNotEmpty) ...[
 const SizedBox(height: 8),
              SignupPasswordStrengthBar(password: _passwordController.text),
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
 prefixIcon: Iconsax.lock_copy,
 suffixIcon: IconButton(
 icon: Icon(_obscureConfirmPassword ? Iconsax.eye_slash_copy : Iconsax.eye_copy, color: VSPColors.textSecondary),
 onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
 ),
 ),
 
 const SizedBox(height: 20),

 
 VSPTermsCheckbox(

 
   value: _agreedToTerms,

 
   onChanged: (val) => setState(() => _agreedToTerms = val),

 
 ),

 
 const SizedBox(height: 20),

 
 PrimaryButton(

 
   text: AppLocalizations.of(context)!.createAccount,
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
),
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
}
