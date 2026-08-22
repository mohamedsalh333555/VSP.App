import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/social_auth_button.dart';
import 'package:go_router/go_router.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/utils/vsp_feedback.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // تم حذف فرض دور اللاعب ليتعرف النظام على دور المستخدم الحقيقي من قاعدة البيانات تلقائياً
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: VSPColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              title: Text(
                AppLocalizations.of(context)!.forgotPassword,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.forgotPasswordSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VSPColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    hintText: AppLocalizations.of(context)!.emailAddress,
                    prefixIcon: Iconsax.sms_copy,
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(color: VSPColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            VSPFeedback.showError(context, AppLocalizations.of(context)!.invalidEmail);
                            return;
                          }
                          setDialogState(() => isLoading = true);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final success = await authProvider.resetPassword(email);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (success) {
                            VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.resetPasswordSuccess);
                          } else {
                            VSPFeedback.showError(context, authProvider.errorMessage ?? AppLocalizations.of(context)!.resetPasswordError);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text(AppLocalizations.of(context)!.submit, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleLogin() async {
    // Basic Validation
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      HapticFeedback.heavyImpact();
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isAr ? 'يرجى إدخال البريد الإلكتروني وكلمة المرور 🔑' : 'Please enter email and password 🔑',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        HapticFeedback.lightImpact();
        // ✅ GoRouter handles declarative navigation to /, /verify-email, /onboarding, or /owner
      }
    } else {
      if (mounted) {
        HapticFeedback.vibrate();
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        final fallbackMsg = isAr ? 'فشل تسجيل الدخول، يرجى التأكد من صحة البريد وكلمة المرور' : 'Login failed. Please check your credentials';
        VSPFeedback.showError(context, authProvider.errorMessage ?? fallbackMsg);
      }
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
        body: Stack(
          children: [
            // 1. Subtle Background Elements
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accentGlow,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24.0, 
                  right: 24.0, 
                  top: 0, 
                  bottom: MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    
                    // Header Nav
                    Row(
                      children: [
                        VSPBackButton(
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/welcome');
                            }
                          },
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
                      AppLocalizations.of(context)!.login,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 48,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.signInSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Login Fields with Header
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
                          AppLocalizations.of(context)!.credentialAccess,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            letterSpacing: 1.1,
                            color: VSPColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    CustomTextField(
                      controller: _emailController,
                      hintText: AppLocalizations.of(context)!.emailAddress,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Iconsax.sms_copy,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      hintText: AppLocalizations.of(context)!.password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _handleLogin();
                      },
                      prefixIcon: Iconsax.lock_copy,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Iconsax.eye_slash_copy : Iconsax.eye_copy,
                          color: VSPColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),

                    
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(context),
                        child: Text(
                          AppLocalizations.of(context)!.forgotPassword,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    VSPAnimatedButton(
                      text: AppLocalizations.of(context)!.login,
                      onPressed: () {
                        if (_isLoading) return;
                        _handleLogin();
                      },
                      isLoading: _isLoading,
                    ),

              const SizedBox(height: 30),

              // ── Divider ──
              Row(
                children: [
                  const Expanded(child: Divider(color: VSPColors.borderLight, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      AppLocalizations.of(context)!.orContinueWith,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.6)),
                    ),
                  ),
                  const Expanded(child: Divider(color: VSPColors.borderLight, thickness: 1)),
                ],
              ),

              const SizedBox(height: 20),

                    Row(
                      children: [
                         if (!kIsWeb && Platform.isIOS) ...[
                           Expanded(
                             child: SocialAuthButton(
                               height: 56,
                               iconWidget: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Image.asset(
                                     'assets/images/apple_logo.png',
                                     width: 20,
                                     height: 20,
                                     color: VSPColors.textPrimary,
                                   ),
                                   const SizedBox(width: 10),
                                   Text(
                                     'Apple',
                                     style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                       fontWeight: FontWeight.bold,
                                       color: VSPColors.textPrimary,
                                     ),
                                   ),
                                 ],
                               ),
                               onPressed: _isLoading ? null : () async {
                                 HapticFeedback.mediumImpact();
                                 setState(() => _isLoading = true);
                                 final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                 final success = await authProvider.signInWithApple(isLoginOnly: true);

                                 if (!context.mounted) return;
                                 setState(() => _isLoading = false);

                                 if (success) {
                                   HapticFeedback.lightImpact();
                                   context.go('/');
                                 } else {
                                   HapticFeedback.vibrate();
                                   final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                   VSPFeedback.showError(context, authProvider.errorMessage ?? (isAr ? 'فشل تسجيل الدخول عبر Apple' : 'Apple Sign-In failed'));
                                 }
                               },
                             ),
                           ),
                           const SizedBox(width: 12),
                         ],

                         Expanded(
                           child: SocialAuthButton(
                             height: 56,
                             iconWidget: Row(
                               mainAxisSize: MainAxisSize.min,
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Image.asset(
                                   'assets/images/google_logo.png',
                                   width: 22,
                                   height: 22,
                                 ),
                                 const SizedBox(width: 10),
                                 Text(
                                   AppLocalizations.of(context)!.google,
                                   style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                     fontWeight: FontWeight.bold,
                                     color: VSPColors.textPrimary,
                                   ),
                                 ),
                               ],
                             ),
                             onPressed: _isLoading ? null : () async {
                               HapticFeedback.mediumImpact();
                               setState(() => _isLoading = true);
                               final authProvider = Provider.of<AuthProvider>(context, listen: false);
                               final success = await authProvider.signInWithGoogle(isLoginOnly: true);

                               if (!context.mounted) return;
                               setState(() => _isLoading = false);

                               if (success) {
                                 HapticFeedback.lightImpact();
                                 context.go('/');
                               } else {
                                 HapticFeedback.vibrate();
                                 final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                 VSPFeedback.showError(context, authProvider.errorMessage ?? (isAr ? 'فشل تسجيل الدخول عبر Google' : 'Google Sign-In failed'));
                               }
                             },
                           ),
                         ),
                      ],
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
}
