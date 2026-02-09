import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../owner/screens/facility_onboarding_screen.dart';
import '../../player/screens/player_home_screen.dart';

/// شاشة نجاح التسجيل - الخطوة 4
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  void _handleGetStarted(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isOwner) {
      // المالك يذهب لمسار تسجيل المنشأة
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilityOnboardingScreen(),
        ),
      );
    } else {
      // اللاعب يذهب للصفحة الرئيسية
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PlayerHomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A3A1A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Success Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonGreen.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: AppTheme.neonGreen,
                  ),
                ),

                const SizedBox(height: 40),

                // Success Title
                Text(
                  languageProvider.getText(AppStrings.accountCreated),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Welcome Message
                Text(
                  languageProvider.getText(AppStrings.welcomeMessage),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Step Indicator
                Text(
                  '4/4',
                  style: TextStyle(
                    color: AppTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Spacer(flex: 3),

                // Get Started Button
                PrimaryButton(
                  text: languageProvider.getText(AppStrings.getStarted),
                  onPressed: () => _handleGetStarted(context),
                ),

                const SizedBox(height: 40),

                // Bottom Indicator
                Container(
                  width: 134,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary,
                    borderRadius: BorderRadius.circular(100),
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
