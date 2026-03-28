import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../core/navigation/root_screen.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // Basic Validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
       VSPFeedback.showError(context, 'Please enter email and password');
       return;
     }

    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
        // ✅ RootScreen handles all navigation gates:
        // - isRegistrationComplete → VerifyEmailScreen (OTP)
        // - hasStadium, isIdentityVerified → Owner onboarding
        // - phone check → SocialOnboardingScreen
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const RootScreen()), 
            (r) => false
          );
        }
    } else {
        if (mounted) {
          VSPFeedback.showError(context, authProvider.errorMessage ?? 'Login Failed');
        }
    }
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
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      hintText: AppLocalizations.of(context)!.password,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline,
                    ),
                    
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
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
                  Expanded(child: Divider(color: VSPColors.divider.withValues(alpha: 0.15), thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      AppLocalizations.of(context)!.orContinueWith,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.6)),
                    ),
                  ),
                  Expanded(child: Divider(color: VSPColors.divider.withValues(alpha: 0.15), thickness: 1)),
                ],
              ),

              const SizedBox(height: 20),

                    Row(
                children: [
                   if (!kIsWeb && Platform.isIOS) ...[
                     Expanded(
                       child: SizedBox(
                         height: 52,
                         child: OutlinedButton.icon(
                           icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                           label: Text(
                             AppLocalizations.of(context)!.apple,
                             style: Theme.of(context).textTheme.labelLarge?.copyWith(
                               color: VSPColors.textPrimary,
                               fontWeight: FontWeight.w500,
                             ),
                           ),
                           style: OutlinedButton.styleFrom(
                             side: BorderSide(color: VSPColors.divider.withValues(alpha: 0.15)),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                             backgroundColor: Colors.black, // Apple black background
                           ),
                           onPressed: _isLoading ? null : () async {
                             setState(() => _isLoading = true);
                             final authProvider = Provider.of<AuthProvider>(context, listen: false);
                             final success = await authProvider.signInWithApple();

                             if (!context.mounted) return;
                             setState(() => _isLoading = false);

                             if (success) {
                               Navigator.of(context).pushAndRemoveUntil(
                                 MaterialPageRoute(builder: (context) => const RootScreen()),
                                 (route) => false,
                               );
                             } else {
                               VSPFeedback.showError(context, authProvider.errorMessage ?? 'Apple Sign-In failed');
                             }
                           },
                         ),
                       ),
                     ),
                     const SizedBox(width: 12),
                   ],

                   Expanded(
                     child: SizedBox(
                       height: 52,
                       child: OutlinedButton.icon(
                         icon: const Text(
                           'G',
                           style: TextStyle(
                             fontSize: 22,
                             fontWeight: FontWeight.w900,
                             color: Color(0xFF4285F4),
                           ),
                         ),
                         label: Text(
                           AppLocalizations.of(context)!.google,
                           style: Theme.of(context).textTheme.labelLarge?.copyWith(
                             color: VSPColors.textPrimary,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                         style: OutlinedButton.styleFrom(
                           side: BorderSide(color: VSPColors.divider.withValues(alpha: 0.15)),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                           backgroundColor: VSPColors.surface,
                         ),
                         onPressed: _isLoading ? null : () async {
                           setState(() => _isLoading = true);
                           final authProvider = Provider.of<AuthProvider>(context, listen: false);
                           final success = await authProvider.signInWithGoogle();

                           if (!context.mounted) return;
                           setState(() => _isLoading = false);

                           if (success) {
                             Navigator.of(context).pushAndRemoveUntil(
                               MaterialPageRoute(builder: (context) => const RootScreen()),
                               (route) => false,
                             );
                           } else {
                             VSPFeedback.showError(context, authProvider.errorMessage ?? 'Google Sign-In failed');
                           }
                         },
                       ),
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
} // end _LoginScreenState
