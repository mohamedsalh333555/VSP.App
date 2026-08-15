import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/social_onboarding_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/auth/screens/set_new_password_screen.dart';
import '../../features/owner/screens/facility_onboarding_screen.dart';
import '../../features/owner/screens/owner_documentation_wizard.dart';
import '../../features/owner/screens/owner_main_screen.dart';
import '../../features/player/screens/player_home_screen.dart';
import '../../features/player/screens/match_details_screen.dart';
import '../../features/player/screens/team_profile_screen.dart';
import '../../features/player/screens/notifications_center_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import 'offline_error_screen.dart';
import 'suspended_account_screen.dart';
import 'root_screen.dart';
import '../../features/player/screens/championship_details_screen.dart';
import '../../core/repositories/tournament_repository.dart';
import '../../data/models.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider, GlobalKey<NavigatorState> navigatorKey) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/splash',
      refreshListenable: authProvider,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const RootScreen(),
        ),
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(navigate: false),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const SocialOnboardingScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) {
            final email = (state.extra as String?) ?? authProvider.email;
            return VerifyEmailScreen(email: email);
          },
        ),
        GoRoute(
          path: '/set-new-password',
          builder: (context, state) => const SetNewPasswordScreen(),
        ),

        GoRoute(
          path: '/facility-onboarding',
          builder: (context, state) => const FacilityOnboardingScreen(),
        ),
        GoRoute(
          path: '/documentation',
          builder: (context, state) => const OwnerDocumentationWizard(),
        ),
        GoRoute(
          path: '/owner',
          builder: (context, state) => const OwnerMainScreen(),
        ),
        GoRoute(
          path: '/player',
          builder: (context, state) => const PlayerHomeScreen(),
        ),
        GoRoute(
          path: '/offline',
          builder: (context, state) => const OfflineErrorScreen(),
        ),
        GoRoute(
          path: '/suspended',
          builder: (context, state) => const SuspendedAccountScreen(),
        ),
        GoRoute(
          path: '/match/:bookingId',
          builder: (context, state) {
            final bookingId = state.pathParameters['bookingId'] ?? '';
            return MatchDetailsScreen(bookingId: bookingId);
          },
        ),
        GoRoute(
          path: '/team/:teamId',
          builder: (context, state) {
            final teamId = state.pathParameters['teamId'] ?? '';
            return TeamProfileScreen(teamId: teamId);
          },
        ),
        GoRoute(
          path: '/championship/:championshipId',
          builder: (context, state) {
            final id = state.pathParameters['championshipId'] ?? '';
            return FutureBuilder<Championship?>(
              future: TournamentRepository().getChampionshipById(id),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return ChampionshipDetailsScreen(championship: snapshot.data!);
                }
                return const Scaffold(
                  backgroundColor: VSPColors.background,
                  body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsCenterScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
      ],
      redirect: (context, state) => redirectLogic(context, state, authProvider),
    );
  }

  static String? redirectLogic(BuildContext context, GoRouterState state, AuthProvider authProvider) {
    final isInitializing = authProvider.isInitializing;
    final isAuthenticated = authProvider.isAuthenticated;
    final isGhostUser = authProvider.isGhostUser;
    final userModel = authProvider.userModel;
    final isOwner = authProvider.isOwner;
    final hasDataFetchError = authProvider.hasDataFetchError;
    
    final path = state.uri.path;

    // 0. Password recovery link bypass
    if (path == '/set-new-password') return null;

    // 1. Session initialization check
    if (isInitializing) {
      if (path != '/splash') return '/splash';
      return null;
    }

    // 2. Unauthenticated check
    if (!isAuthenticated) {
      if (path != '/welcome') return '/welcome';
      return null;
    }

    // 3. Ghost user onboarding check
    if (isGhostUser) {
      if (path != '/onboarding') return '/onboarding';
      return null;
    }

    // 4. User data loading check
    if (userModel == null) {
      if (authProvider.isLoading || authProvider.isInitializing) {
        if (path != '/splash') return '/splash';
        return null;
      }
      if (hasDataFetchError) {
        if (path != '/offline') return '/offline';
        return null;
      }
      if (path != '/splash') return '/splash';
      return null;
    }

    // 5. OTP verification block
    // Checks isEmailVerified — NOT isRegistrationComplete.
    // Google/Apple users are already email-verified by the provider → skip this gate.
    // Email/password users must verify their OTP before proceeding.
    if (!userModel.isEmailVerified) {
      if (path != '/verify-email') return '/verify-email';
      return null;
    }

    // 6. Registration detail check (missing phone)
    final bool hasPhone = userModel.phone != null && userModel.phone!.trim().isNotEmpty && userModel.phone!.trim().length >= 10;
    if (!hasPhone) {
      if (path != '/onboarding') return '/onboarding';
      return null;
    }

    // 6.5 Admin role check
    final bool isAdmin = userModel.role == 'admin' || userModel.role == 'co_founder';
    if (isAdmin) {
      if (path == '/admin') return null;
      if (path == '/welcome' || path == '/splash' || path == '/onboarding') return '/admin';
    }

    if (userModel.isBlocked) {
      if (isOwner) {
        // Suspended/Blocked owners proceed to owner dashboard with alert
        if (path != '/owner') return '/owner';
        return null;
      } else {
        // Blocked players locked out completely
        if (path != '/suspended') return '/suspended';
        return null;
      }
    }

    // 7. Owner flow gating
    if (isOwner) {
      // 🛡️ ROLE ISOLATION: Owners must NOT view player match or team details.
      if (path.startsWith('/match/') || path.startsWith('/team/')) {
        return '/owner';
      }

      final bool isOnboardingConfirmed = userModel.additionalData?['isOnboardingConfirmed'] == true;
      
      if (!userModel.hasStadium || !isOnboardingConfirmed) {
        if (path != '/facility-onboarding') return '/facility-onboarding';
        return null;
      }

      // 🛡️ FIX GATING BUG:
      // If the owner has a stadium, they must be allowed to stay on /facility-onboarding
      // so they can see their added stadiums list, add more, or manually proceed.
      // Likewise, allow them to stay on /documentation to upload docs.
      if (path == '/facility-onboarding' || path == '/documentation') {
        return null;
      }

      // 🛡️ SECURITY AUDIT FIX: Owner Verification Gate
      // Unverified owners who have not submitted documents MUST be routed to /documentation.
      if (!userModel.isIdentityVerified) {
        final status = userModel.verificationStatus?.toLowerCase();
        if (status == null || status == 'unsubmitted' || status == 'none' || status.isEmpty) {
          if (path != '/documentation') return '/documentation';
          return null;
        }
      }
      
      // Redirect fully onboarded owners to RootScreen
      if (path == '/welcome' || path == '/splash' || path == '/onboarding' || path == '/verify-email' || path == '/owner' || path == '/player' || path == '/offline') {
        return '/';
      }
      return null;
    }

    // 8. Player flow gating
    if (path == '/welcome' || path == '/splash' || path == '/onboarding' || path == '/suspended' || path == '/verify-email' || path == '/player') {
      return '/';
    }

    return null;
  }
}

