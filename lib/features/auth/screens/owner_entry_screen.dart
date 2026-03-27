// LEGACY - not used in active orientation (using SignupScreen)
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart'; // Import Provider
import '../../../core/constants/create_account_strings.dart'; // Import Strings
import '../../../core/providers/language_provider.dart'; // Import LanguageProvider

import '../../owner/screens/owner_stadiums_screen.dart';
import 'owner_email_input_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Owner Entry Screen
class OwnerEntryScreen extends StatelessWidget {
  final bool isOwner;

  const OwnerEntryScreen({
    super.key,
    this.isOwner = true,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: VSPColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(height: 60),

                // Title - "Hi Owner" (Dynamic) with Dev Shortcut
                GestureDetector(
                  // 🔒 DEV ONLY: Double-tap to skip owner onboarding.
                  // Disabled in production (kDebugMode = false in release builds).
                  onDoubleTap: kDebugMode ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dev Mode: Navigating to Owner Dashboard'),
                        backgroundColor: VSPColors.accent,
                        duration: Duration(seconds: 1),
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OwnerStadiumsScreen(isDevMode: true),
                      ),
                    );
                  } : null,
                  child: Text(
                    languageProvider.getText(CreateAccountStrings.hiPitch), 
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  languageProvider.getText(CreateAccountStrings.createNewAccount),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: VSPColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                // Description
                Text(
                  languageProvider.getText(CreateAccountStrings.ownerSubtitle), 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary,
                    height: 1.6,
                  ),
                ),

                const Spacer(),

                // Continue With Email Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OwnerEmailInputScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: VSPColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue With Email',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Social Login Buttons
                // Social Login Buttons
                Row(
                  children: [
                    if (!kIsWeb && Platform.isIOS) ...[
                      Expanded(
                        child: _SocialButton(
                          icon: Icons.apple,
                          // Apple Sign-In not yet implemented: button is shown but disabled.
                          // Rule of Honesty: no misleading "coming soon" message.
                          // TODO(iOS): Implement sign_in_with_apple package when Apple Developer account provisioning is completed.
                          onTap: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _SocialButton(
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
                            const SizedBox(width: 10),
                            Text(
                              languageProvider.isArabic ? 'جوجل' : 'Google',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: VSPColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // TODO: Google Sign In logic
                        },
                      ),
                    ),
                  ],
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
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap; // nullable: null = disabled

  const _SocialButton({
    this.icon,
    this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: VSPColors.divider,
            width: 1.5,
          ),
        ),
        child: Center(
          child: iconWidget ?? (icon != null
              ? Icon(icon, color: VSPColors.textPrimary, size: 28)
              : const SizedBox.shrink()),
        ),
      ),
    );
  }
}

