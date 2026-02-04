import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/data_migration.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';
import 'owner_entry_screen.dart';


/// Welcome Screen - Initial landing page
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 60), // Space where logo/top once was

                // Logo with soft diffused glow (Increased Blur) and Secret Migration Trigger
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 280, // Slightly larger for spread
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonGreen.withOpacity(0.08), // Subtle
                            blurRadius: 120, // Increased for more diffusion
                            spreadRadius: 40,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onLongPress: () async {
                        // Secret Trigger for Data Migration
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Starting Data Migration...')),
                        );
                        await DataMigration().seedDatabase();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Data Migration Completed!')),
                          );
                        }
                      },
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 180,
                        height: 180,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'VSP',
                              style: TextStyle(
                                color: AppTheme.neonGreen,
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Welcome Title - English Only
                const Text(
                  'Welcome to VSP',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Subtitle - English, Medium weight, Clean White
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Book your pitch easily and join teams',
                    style: TextStyle(
                      color: Colors.white, // Clean White
                      fontSize: 15,
                      height: 1.7,
                      fontWeight: FontWeight.w500, // Medium as requested
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 2),

                // User Type Buttons
                Column(
                  children: [
                    // Player Button - Correct Shadow Padding
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4), // Breathing room for shadow
                      child: _AuthButton(
                        label: 'I am a Player',
                        backgroundColor: AppTheme.neonGreen,
                        textColor: Colors.black,
                        onTap: () {
                          authProvider.setUserType('player');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateAccountScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Owner Button - Exact 12 radius and 1.5 border
                    _AuthButton(
                      label: 'I am Stadium Owner',
                      backgroundColor: Colors.transparent,
                      textColor: Colors.white,
                      isOutlined: true,
                      onTap: () {
                        authProvider.setUserType('owner');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OwnerEntryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Footer - English
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppTheme.neonGreen, // #9FDF02 from theme
                          fontSize: 14,
                          fontWeight: FontWeight.bold, // Bold as requested
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Corrected Auth Button with 12px fix
class _AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final bool isOutlined;

  const _AuthButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    const double radius = 12.0; // Exact 12 as requested
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: 58,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor,
            side: const BorderSide(color: AppTheme.neonGreen, width: 1.5), // 1.5 Width
            shape: shape,
            elevation: 0,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 4,
          shadowColor: backgroundColor.withOpacity(0.3),
          shape: shape,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
