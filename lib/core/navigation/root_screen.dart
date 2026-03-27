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
import '../../features/auth/screens/verify_email_screen.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../features/player/screens/match_details_screen.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import '../services/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Timer? _loadingTimeout;
  bool _loadingTimedOut = false;

  @override
  void initState() {
    super.initState();
    _initRemoteConfig();
    _initDeepLinks();
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
        _loadingTimeout = Timer(const Duration(seconds: 10), () {
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

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check for initial link when app starts
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen to incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Handling deep link: $uri');
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // 🛡️ AUTH GUARD: If not fully authenticated/onboarded, save for later
    if (!auth.isAuthenticated || auth.userModel?.isRegistrationComplete != true) {
      debugPrint('💾 Saving pending deep link for after login: $uri');
      SharedPreferences.getInstance().then((prefs) => prefs.setString('pending_deep_link', uri.toString()));
      return;
    }

    // Pattern: https://vsp.app/match/BOOKING_ID
    if (uri.pathSegments.length >= 2) {
      final type = uri.pathSegments[0]; // match, team, etc.
      final id = uri.pathSegments[1];

      if (type == 'match') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchDetailsScreen(bookingId: id),
          ),
        );
      }
    }
  }

  void _checkAndNavigatePendingDeepLink() {
    SharedPreferences.getInstance().then((prefs) {
      final pendingLink = prefs.getString('pending_deep_link');
      if (pendingLink != null) {
        prefs.remove('pending_deep_link');
        final uri = Uri.parse(pendingLink);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(uri);
        });
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
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
      // 🛡️ Timeout Safety Net: after 10s show a connection error with sign-out option
      if (_loadingTimedOut) {
        return Scaffold(
          backgroundColor: VSPColors.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: VSPColors.textSecondary, size: 56),
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
                        await auth.signOut();
                      },
                      child: const Text('Sign Out & Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
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

    // 4. Registration NOT complete → Verify Email/OTP
    if (!user.isRegistrationComplete) {
      return const VerifyEmailScreen();
    }

    // 5. Shared Moderation Check
    if (user.isSuspended == true) {
      return SuspendedAccountScreen(debt: user.commissionDebt);
    }

    // 6. Owner Flow
    if (auth.isOwner) {
      // 6.1. Facility Setup (Stadium)
      if (!user.hasStadium) {
        return const FacilityOnboardingScreen();
      }

      // 6.2. Identity Verification (Documents)
      if (!user.isIdentityVerified) {
        return const OwnerDocumentationWizard();
      }

      _checkAndNavigatePendingDeepLink();
      return const OwnerMainScreen();
    }

    // 7. Player → Dashboard
    _checkAndNavigatePendingDeepLink();
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
              const Icon(Icons.settings_suggest_rounded, size: 80, color: VSPColors.accent),
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
