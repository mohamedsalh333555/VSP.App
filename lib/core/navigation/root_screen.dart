import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/widgets/primary_button.dart';
import '../../features/auth/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/owner/screens/owner_main_screen.dart';
import '../../features/player/screens/player_home_screen.dart';
import '../../features/auth/screens/social_onboarding_screen.dart';
import '../../features/owner/screens/facility_onboarding_screen.dart';
import '../../features/owner/screens/owner_documentation_wizard.dart';
import 'suspended_account_screen.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../features/player/screens/match_details_screen.dart';
import 'dart:async';
import '../services/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  Timer? _loadingTimeout;
  bool _loadingTimedOut = false;

  @override
  void initState() {
    super.initState();
    _initRemoteConfig();
    // 📍 Trigger location check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // Only run for authenticated players (Owners have fixed stadium locations usually)
      if (auth.isAuthenticated && !auth.isOwner) {
        auth.updateUserLocation();
      }

      // 🛡️ Safety Net: If user is authenticated but userModel never loads within
      // 3 seconds (e.g. Firestore offline), show a Connection Error screen.
      if (auth.isAuthenticated && auth.userModel == null) {
        _loadingTimeout = Timer(const Duration(seconds: 5), () {
          if (mounted && auth.userModel == null) {
            setState(() => _loadingTimedOut = true);
          }
        });
      }
    });
  }

  Future<void> _initRemoteConfig() async {
    final remoteConfig = RemoteConfigService();
    await remoteConfig.initialize();
    if (mounted) setState(() {});
    
    final shouldUpdate = await remoteConfig.shouldForceUpdate();
    if (shouldUpdate && mounted) {
      _showForceUpdateDialog(remoteConfig.forceUpdateUrl);
    }
  }

  void _showForceUpdateDialog(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: const Text('Update Required 🚀', style: TextStyle(color: Colors.white)),
        content: const Text(
          'A new version of VSP is available with improved performance and new features.',
          style: TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          PrimaryButton(
            text: 'Update Now',
            onPressed: () {
              // TODO: Launch Store URL
            },
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final remoteConfig = RemoteConfigService();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: _buildRootContent(auth, remoteConfig),
    );
  }

  Widget _buildRootContent(AuthProvider auth, RemoteConfigService remoteConfig) {

    // 0. Maintenance Mode
    if (remoteConfig.isMaintenanceMode) {
      return const MaintenanceScreen();
    }

    // 0.1 Initializing Session Stability 
    if (auth.isInitializing) {
      return const SplashScreen(navigate: false);
    }

    // 1. Not Authenticated → Welcome
    if (!auth.isAuthenticated) {
      return const WelcomeScreen();
    }

    // 2. Ghost User Detection → Redirect to Profile Completion
    if (auth.isGhostUser) {
      return const SocialOnboardingScreen();
    }

    // 3. Authenticated but waiting for User Data → Splash (Loading)
    if (auth.isAuthenticated && auth.userModel == null) {
      // 🛡️ Timeout Safety Net: after 5s show a connection error with sign-out option
      if (_loadingTimedOut) {
        return Scaffold(
          backgroundColor: VSPColors.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.wifiOff, color: VSPColors.textSecondary, size: 56),
                  const SizedBox(height: 24),
                  Text(
                    'Connection Problem',
                    style: TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load your profile. Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VSPColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: VSPColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await auth.retryDataFetch();
                      },
                      child: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        await auth.signOut();
                      },
                      child: const Text('Sign Out', style: TextStyle(color: VSPColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const SplashScreen(navigate: false);
    }

    final user = auth.userModel!;

    // 3. Prevent bypass: Social Login users missing phone → Complete Profile
    if (user.phone == null || user.phone!.isEmpty) {
      return const SocialOnboardingScreen();
    }

    if (user.isBlocked && !auth.isOwner) {
      return const SuspendedAccountScreen();
    }

    // 6. Owner Flow
    if (auth.isOwner) {
      // 6.1. Facility Setup (Stadium)
      if (!user.hasStadium) {
        return const FacilityOnboardingScreen();
      }

      // 6.2. Identity Verification (Documents)
      if (!user.isIdentityVerified && user.verificationStatus != 'pending') {
        return const OwnerDocumentationWizard();
      }

      return const OwnerMainScreen();
    }

    // 7. Player → Dashboard
    return const PlayerHomeScreen();
  }
}

// ─────────────────────────────────────────────
// 🛠️ Maintenance Mode Screen
// ─────────────────────────────────────────────
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.settings, size: 80, color: VSPColors.accent),
              const SizedBox(height: VSPSpacing.xl),
              Text(
                'We’ll be back soon!',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VSPSpacing.md),
              const Text(
                'VSP is currently undergoing scheduled maintenance to improve your experience. We apologize for the inconvenience.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VSPColors.textSecondary),
              ),
              const SizedBox(height: VSPSpacing.xl),
              CircularProgressIndicator(color: VSPColors.accent.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}


