import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/owner/screens/owner_main_screen.dart';
import '../../features/player/screens/player_home_screen.dart';
import '../../features/auth/screens/social_onboarding_screen.dart';
import '../../features/owner/screens/facility_onboarding_screen.dart';
import '../../features/owner/screens/owner_documentation_wizard.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../core/theme/app_theme.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 1. Show Loading while fetching user data or auth state
    if (auth.isLoading || (auth.isAuthenticated && auth.userModel == null)) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 120, fit: BoxFit.contain),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppTheme.neonGreen),
            ],
          ),
        ),
      );
    }

    // 2. User is not authenticated → WelcomeScreen
    if (!auth.isAuthenticated) {
      return const WelcomeScreen();
    }

    // 3. userModel is null (fallback safety)
    if (auth.userModel == null) {
      return const WelcomeScreen();
    }

    // 4. Registration NOT complete → OTP Verification Screen
    // This is the ONLY gate for email-based verification
    if (!auth.userModel!.isRegistrationComplete) {
      return const VerifyEmailScreen();
    }

    // 5. Social Login users missing phone → Complete profile first
    if (auth.userModel?.phone == null || auth.userModel!.phone!.isEmpty) {
      return const SocialOnboardingScreen();
    }

    // 6. Owner Onboarding Gating
    if (auth.isOwner) {
      final user = auth.userModel!;

      // 6.1. Facility Setup (Stadium)
      if (!user.hasStadium) {
        return const FacilityOnboardingScreen();
      }

      // 6.2. Identity Verification (Documents)
      if (!user.isIdentityVerified) {
        return const OwnerDocumentationWizard();
      }

      return const OwnerMainScreen();
    }

    // 7. Player → Dashboard
    return const PlayerHomeScreen();
  }
}
