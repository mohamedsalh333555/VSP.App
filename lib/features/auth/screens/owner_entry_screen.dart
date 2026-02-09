import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../../../core/constants/create_account_strings.dart'; // Import Strings
import '../../../core/providers/language_provider.dart'; // Import LanguageProvider
import '../../../core/theme/app_theme.dart';
import '../../owner/screens/owner_stadiums_screen.dart';
import 'owner_email_input_screen.dart';

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
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(height: 60),

                // Title - "Hi Owner" (Dynamic) with Dev Shortcut
                GestureDetector(
                  onDoubleTap: () {
                    // Dev Mode Shortcut
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dev Mode: Navigating to Owner Dashboard'),
                        backgroundColor: AppTheme.neonGreen,
                        duration: Duration(seconds: 1),
                      ),
                    );
                    
                    // Navigate directly to populated Owner Stadiums Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OwnerStadiumsScreen(isDevMode: true),
                      ),
                    );
                  },
                  child: Text(
                    languageProvider.getText(CreateAccountStrings.hiPitch), // Use Dynamic String
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Agency FB',
                      letterSpacing: -1,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  languageProvider.getText(CreateAccountStrings.createNewAccount),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                // Description
                Text(
                  languageProvider.getText(CreateAccountStrings.ownerSubtitle), // Use Dynamic String
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
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
                      backgroundColor: AppTheme.neonGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue With Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Social Login Buttons
                Row(
                  children: [
                    Expanded(
                      child: _SocialButton(
                        icon: Icons.apple,
                        onTap: () {
                          // TODO: Apple Sign In
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialButton(
                        icon: Icons.facebook,
                        onTap: () {
                          // TODO: Facebook Sign In
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SocialButton(
                        iconPath: 'G', // Google icon placeholder
                        onTap: () {
                          // TODO: Google Sign In
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
                      color: AppTheme.textPrimary,
                      borderRadius: BorderRadius.circular(100),
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

class _SocialButton extends StatelessWidget {
  final IconData? icon;
  final String? iconPath;
  final VoidCallback onTap;

  const _SocialButton({
    this.icon,
    this.iconPath,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: AppTheme.textPrimary, size: 28)
              : Text(
                  iconPath!,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
