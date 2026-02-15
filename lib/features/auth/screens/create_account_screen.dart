import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/create_account_strings.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'add_email_screen.dart';
import '../../owner/screens/owner_email_input_screen.dart';

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
    // Use local isOwner parameter for stability, fallback to provider if needed
    final bool isUserOwner = isOwner; 

    // تحديد النصوص بناءً على نوع المستخدم
    final String greeting = !isUserOwner
        ? languageProvider.getText(CreateAccountStrings.hiSporty)
        : languageProvider.getText(CreateAccountStrings.hiPitch);

    final String subtitle = !isUserOwner
        ? languageProvider.getText(CreateAccountStrings.playerSubtitle)
        : languageProvider.getText(CreateAccountStrings.ownerSubtitle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.darkBackground, // Fallback to background color
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
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
                  color: AppTheme.textPrimary,
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 34, // Slightly larger to compensate for default font
                    fontWeight: FontWeight.w900, // Stay as extra bold as possible
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.3, // Tighter line height
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 50), // Added more vertical space

              // Continue With Email Button
              _NeonButton(
                text: languageProvider.getText(CreateAccountStrings.continueWithEmail),
                onPressed: () {
                  if (isUserOwner) {
                    authProvider.setUserType('owner');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OwnerEmailInputScreen(),
                      ),
                    );
                  } else {
                    authProvider.setUserType('player');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddEmailScreen(),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // OR Divider
              Center(
                child: Text(
                  languageProvider.getText(CreateAccountStrings.or),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Social Login Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialButton(
                    icon: Icons.apple,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 12),
                  _SocialButton(
                    icon: Icons.facebook,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 12),
                  _SocialButton(
                    iconWidget: CachedNetworkImage(
                      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                      width: 24,
                      height: 24,
                      placeholder: (context, url) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
                      errorWidget: (context, url, error) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
                    ),
                    onPressed: () {},
                  ),
                ],
              ),

              const Spacer(),

              // Terms and Privacy Policy (Single line bold link)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'By using VSP, you agree to the Terms and '),
                        TextSpan(
                          text: 'Privacy Policy.',
                          style: const TextStyle(
                            color: AppTheme.neonGreen,
                            fontWeight: FontWeight.bold, // Bold
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Indicator
              Center(
                child: Container(
                  width: 134,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
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
          backgroundColor: AppTheme.neonGreen,
          foregroundColor: Colors.black, // Explicitly Black Text
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
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

  const _SocialButton({
    this.icon,
    this.iconWidget,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 105, // Slightly wider
        height: 64, // Increased height
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16.0), // 16.0 Radius
          border: Border.all(
            color: const Color(0xFF2A2A2A), // Subtle dark grey border
            width: 1.5,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Padding to make icon smaller
            child: iconWidget ??
                Icon(
                  icon,
                  color: AppTheme.textPrimary,
                  size: 24, // Smaller icon size
                ),
          ),
        ),
      ),
    );
  }
}
