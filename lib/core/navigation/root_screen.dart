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
import '../../features/auth/screens/splash_screen.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    // 📍 Trigger location check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // Only run for authenticated players (Owners have fixed stadium locations usually)
      if (auth.isAuthenticated && !auth.isOwner) {
        auth.updateUserLocation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 1. Loading State or Waiting for User Data → Show Splash
    if (auth.isLoading || (auth.isAuthenticated && auth.userModel == null)) {
      return auth.hasDataFetchError
          ? Scaffold(
              backgroundColor: AppTheme.darkBackground,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SplashScreen(navigate: false),
                    const SizedBox(height: 16),
                    const Text('Connection issue. Retrying...',
                        style: TextStyle(color: Colors.white54)),
                    TextButton(
                      onPressed: () => auth.signOut(),
                      child: const Text('Sign out',
                          style: TextStyle(color: Colors.amber)),
                    ),
                  ],
                ),
              ),
            )
          : const SplashScreen(navigate: false);
    }

    // 2. Not Authenticated → Welcome
    if (!auth.isAuthenticated) {
      return const WelcomeScreen();
    }

    // 3. Social Login users missing phone → Complete profile
    if (auth.userModel?.phone == null || auth.userModel!.phone!.isEmpty) {
      return const SocialOnboardingScreen();
    }

    // 4. Registration NOT complete → OTP Verification
    if (!auth.userModel!.isRegistrationComplete) {
      return const VerifyEmailScreen();
    }

    // 5. Owner Flow
    if (auth.isOwner) {
      final user = auth.userModel!;

      // 🔴 KILL SWITCH: Suspended accounts get blocked immediately
      if (user.isSuspended) {
        return SuspendedAccountScreen(debt: user.commissionDebt);
      }

      // 5.1. Facility Setup (Stadium)
      if (!user.hasStadium) {
        return const FacilityOnboardingScreen();
      }

      // 5.2. Identity Verification (Documents)
      if (!user.isIdentityVerified) {
        return const OwnerDocumentationWizard();
      }

      return const OwnerMainScreen();
    }

    // 6. Player → Dashboard
    return const PlayerHomeScreen();
  }
}

// ─────────────────────────────────────────────
// 🛑 Suspended Account Screen
// Shown when an owner's isSuspended == true in Firestore.
// Admin can unblock by setting isSuspended: false remotely.
// ─────────────────────────────────────────────
class SuspendedAccountScreen extends StatelessWidget {
  final double debt;
  const SuspendedAccountScreen({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: const Icon(Icons.block_rounded,
                    size: 50, color: Colors.redAccent),
              ),
              const SizedBox(height: VSPSpacing.xl),

              // Title
              Text(
                'Account Suspended',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VSPSpacing.md),

              // Subtitle
              Text(
                'Your account has been temporarily suspended due to outstanding commission payments.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: VSPColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VSPSpacing.xl),

              // Debt Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(VSPSpacing.lg),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Outstanding Balance',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: VSPColors.textSecondary),
                    ),
                    const SizedBox(height: VSPSpacing.sm),
                    Text(
                      '${debt.toStringAsFixed(0)} EGP',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VSPSpacing.xl),

              // Contact Support Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Launch WhatsApp or in-app support
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                  ),
                  icon: const Icon(Icons.support_agent),
                  label: const Text(
                    'Contact Support to Pay',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: VSPSpacing.md),

              // Sign Out
              TextButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                child: Text(
                  'Sign Out',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: VSPColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
