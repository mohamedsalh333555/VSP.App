import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import 'package:go_router/go_router.dart';
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
    _emailController.text = 'owner_test@vsp.com';
    _passwordController.text = '12345678';
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
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.emailAddress,
                      hintStyle: const TextStyle(color: VSPColors.textSecondary),
                      prefixIcon: Icon(Iconsax.sms, color: VSPColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: VSPColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
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
        if (mounted) {
          context.go('/');
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
                        _buildNavCircle(
                          context, 
                          icon: languageProvider.isArabic ? Iconsax.arrow_right_3 : Iconsax.arrow_left_1,
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
                      textInputAction: TextInputAction.next,
                      prefixIcon: Iconsax.sms,
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
                      prefixIcon: Iconsax.lock,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Iconsax.eye : Iconsax.eye_slash,
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
                             child: _SocialButton(
                               height: 56,
                               icon: LucideIcons.apple,
                               onPressed: _isLoading ? null : () async {
                                 setState(() => _isLoading = true);
                                 final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                 final success = await authProvider.signInWithApple();

                                 if (!context.mounted) return;
                                 setState(() => _isLoading = false);

                                 if (success) {
                                   context.go('/');
                                 } else {
                                   VSPFeedback.showError(context, authProvider.errorMessage ?? 'Apple Sign-In failed');
                                 }
                               },
                             ),
                           ),
                           const SizedBox(width: 12),
                         ],

                         Expanded(
                           child: _SocialButton(
                             height: 56,
                             iconWidget: Row(
                               mainAxisSize: MainAxisSize.min,
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Container(
                                   width: 24,
                                   height: 24,
                                   decoration: const BoxDecoration(
                                     color: VSPColors.textPrimary,
                                     shape: BoxShape.circle,
                                   ),
                                   child: const Center(
                                     child: Text(
                                       'G', 
                                       style: TextStyle(
                                         color: VSPColors.background, 
                                         fontWeight: FontWeight.w900, 
                                         fontSize: 14
                                       )
                                     )
                                   ),
                                 ),
                                 const SizedBox(width: 12),
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
                               setState(() => _isLoading = true);
                               final authProvider = Provider.of<AuthProvider>(context, listen: false);
                               final success = await authProvider.signInWithGoogle();

                               if (!context.mounted) return;
                               setState(() => _isLoading = false);

                               if (success) {
                                 context.go('/');
                               } else {
                                 VSPFeedback.showError(context, authProvider.errorMessage ?? 'Google Sign-In failed');
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
} // end _LoginScreenState

/// زر تسجيل دخول اجتماعي موحد مع إطار متدرج وخلفية أسطح داكنة
class _SocialButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final double? height;

  const _SocialButton({
    this.icon,
    this.iconWidget,
    required this.onPressed,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: CustomPaint(
        painter: _GradientBorderPainter(
          strokeWidth: 1.5,
          radius: VSPRadius.md,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.30),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.30),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Container(
          width: double.infinity,
          height: height ?? 56,
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: iconWidget ??
                  Icon(
                    icon,
                    color: VSPColors.textPrimary,
                    size: 24,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// رسام الإطار المتدرج الاحترافي للأزرار والأسطح
class _GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;
  final Gradient gradient;

  _GradientBorderPainter({
    required this.strokeWidth,
    required this.radius,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius - strokeWidth / 2),
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) => false;
}


