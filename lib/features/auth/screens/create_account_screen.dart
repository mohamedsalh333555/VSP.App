import '../../../core/ui/tokens/vsp_tokens.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/create_account_strings.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';

import 'signup_screen.dart';
import '../../../core/navigation/root_screen.dart';

/// شاشة إنشاء حساب جديد - تظهر بعد اختيار الدور
class CreateAccountScreen extends StatelessWidget {
  final bool isOwner;

  const CreateAccountScreen({
    super.key,
    this.isOwner = false, // Default to player to be safe
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isUserOwner = isOwner;
    // Google Sign-In only supported on mobile (Android/iOS)
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    // تحديد النصوص بناءً على نوع المستخدم
    final String greeting = !isUserOwner
        ? languageProvider.getText(CreateAccountStrings.hiSporty)
        : languageProvider.getText(CreateAccountStrings.hiPitch);

    final String subtitle = !isUserOwner
        ? languageProvider.getText(CreateAccountStrings.playerSubtitle)
        : languageProvider.getText(CreateAccountStrings.ownerSubtitle);

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
          bottom: true, // Allow background to extend
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
                  color: VSPColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(height: 40),

              const SizedBox(height: 50), // Spacing from top back button

              // Greeting - Hi Pitch
              Center(
                child: Text(
                  greeting,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Title - Create new account
              Center(
                child: Text(
                  languageProvider.getText(CreateAccountStrings.createNewAccount),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Subtitle - Controlled width, 3 lines max, centered
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.textSecondary.withValues(alpha: 0.6),
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 50), // Added more vertical space

              _NeonButton(
                text: languageProvider.getText(CreateAccountStrings.continueWithEmail),
                onPressed: () {
                  authProvider.setUserType(isUserOwner ? 'owner' : 'player');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SignupScreen(isOwner: isUserOwner),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              // OR Divider
              Center(
                child: Text(
                  languageProvider.getText(CreateAccountStrings.or),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.6)),
                ),
              ),

              const SizedBox(height: 24),

              // Google Sign-In Button (Mobile Only)
              if (isMobile) ...([
                SizedBox(
                  width: double.infinity,
                  child: _SocialButton(
                    width: double.infinity,
                    height: 60,
                    iconWidget: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CachedNetworkImage(
                          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                          width: 24,
                          height: 24,
                          placeholder: (context, url) =>
                              const Icon(Icons.g_mobiledata, color: VSPColors.textPrimary, size: 24),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.g_mobiledata, color: VSPColors.textPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: VSPColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    onPressed: () async {
                      authProvider.setUserType(isUserOwner ? 'owner' : 'player');
                      final success = await authProvider.signInWithGoogle();
                      if (success && context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const RootScreen()),
                          (route) => false,
                        );
                      } else if (authProvider.errorMessage != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(authProvider.errorMessage!)),
                        );
                      }
                    },
                  ),
                ),
              ]),

              // Terms and Privacy Policy (Single line bold link)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VSPColors.textSecondary.withValues(alpha: 0.54),
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'By using VSP, you agree to the Terms and '),
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

/// زر أخضر نيون كبير
class _NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _NeonButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60, // Increased height
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: VSPColors.accent,
          foregroundColor: VSPColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// زر تسجيل دخول اجتماعي
class _SocialButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onPressed;
  final double? width;
  final double? height;

  const _SocialButton({
    super.key,
    this.icon,
    this.iconWidget,
    required this.onPressed,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width ?? 105,
        height: height ?? 64,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: VSPColors.divider,
            width: 1.5,
          ),
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
    );
  }
}

