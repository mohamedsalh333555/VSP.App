import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/create_account_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/player_onboarding_screen.dart';
import '../../features/auth/screens/owner_onboarding_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/auth/screens/set_new_password_screen.dart';
import '../../features/auth/screens/select_role_screen.dart';
import '../../features/owner/screens/facility_onboarding_screen.dart';
import '../../features/owner/screens/owner_documentation_wizard.dart';
import '../../features/owner/screens/owner_main_screen.dart';
import '../../features/player/screens/player_home_screen.dart';
import '../../features/player/screens/match_details_screen.dart';
import '../../features/player/screens/team_profile_screen.dart';
import '../../features/player/screens/notifications_center_screen.dart';
import 'offline_error_screen.dart';
import 'suspended_account_screen.dart';
import 'root_screen.dart';
import '../../features/player/screens/championship_details_screen.dart';
import '../../core/repositories/tournament_repository.dart';
import '../../data/models.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../features/copilot/screens/vsp_copilot_screen.dart';
import '../../features/copilot/screens/copilot_test_playground.dart';
import '../../features/player/screens/payment_gateway_screen.dart';

class AppRouter {
 static GoRouter createRouter(AuthProvider authProvider, GlobalKey<NavigatorState> navigatorKey) {
 return GoRouter(
 navigatorKey: navigatorKey,
 initialLocation: '/splash',
 refreshListenable: authProvider,
 errorBuilder: (context, state) => const RootScreen(),
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
 path: '/login',
 builder: (context, state) => const LoginScreen(),
 ),
 GoRoute(
 path: '/create-account-player',
 builder: (context, state) => const CreateAccountScreen(isOwner: false),
 ),
 GoRoute(
 path: '/create-account-owner',
 builder: (context, state) => const CreateAccountScreen(isOwner: true),
 ),
 GoRoute(
 path: '/signup-player',
 builder: (context, state) => const SignupScreen(isOwner: false),
 ),
 GoRoute(
 path: '/signup-owner',
 builder: (context, state) => const SignupScreen(isOwner: true),
 ),
 GoRoute(
 path: '/onboarding-player',
 builder: (context, state) => const PlayerOnboardingScreen(),
 ),
 GoRoute(
 path: '/onboarding-owner',
 builder: (context, state) => const OwnerOnboardingScreen(),
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
 path: '/select-role',
 builder: (context, state) => const SelectRoleScreen(),
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
 path: '/copilot',
 builder: (context, state) => const VspCopilotScreen(),
 ),
 GoRoute(
 path: '/copilot-playground',
 builder: (context, state) => const CopilotTestPlayground(),
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
 path: '/checkout',
 builder: (context, state) {
 final params = (state.extra as Map<String, dynamic>?) ?? {};
 final bookingId = params['booking_id']?.toString();
 final stadiumId = params['stadium_id']?.toString() ?? '';
 final stadiumName = params['stadium_name']?.toString() ?? '';
 final ownerId = params['owner_id']?.toString() ?? '';
 final totalPrice = (params['total_price'] as num?)?.toDouble() ?? 0.0;
 final depositAmount = (params['deposit_amount'] as num?)?.toDouble() ?? 0.0;
 final startTimeStr = params['start_time']?.toString();
 final endTimeStr = params['end_time']?.toString();

 DateTime startTime = DateTime.now();
 if (startTimeStr != null && startTimeStr.isNotEmpty) {
   startTime = DateTime.tryParse(startTimeStr) ?? DateTime.now();
 } else if (params['date'] != null && params['time'] != null) {
   final rawDate = params['date'].toString();
   final rawTime = params['time'].toString();
   startTime = DateTime.tryParse('$rawDate $rawTime') ?? DateTime.now();
 }

 DateTime endTime = startTime.add(const Duration(hours: 1));
 if (endTimeStr != null && endTimeStr.isNotEmpty) {
   endTime = DateTime.tryParse(endTimeStr) ?? endTime;
 }

 final draft = BookingDraft(
 stadiumId: stadiumId,
 stadiumName: stadiumName,
 ownerId: ownerId,
 startTime: startTime,
 endTime: endTime,
 bookingType: BookingType.personal,
 isPrivate: false,
 rentBall: params['rent_ball'] == true,
 totalPrice: totalPrice,
 needsDeposit: depositAmount > 0,
 depositPaid: 0.0,
 );

 return PaymentGatewayScreen(
 bookingDraft: draft,
 existingBookingId: bookingId,
 );
 },
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
 const allowedAuthPaths = [
 '/welcome',
 '/login',
 '/create-account-player',
 '/create-account-owner',
 '/signup-player',
 '/signup-owner',
 '/verify-email',
 ];
 if (!allowedAuthPaths.contains(path)) return '/welcome';
 return null;
 }

 // 3. Ghost user onboarding check
  if (isGhostUser) {
    final role = authProvider.userType ?? authProvider.userModel?.role;
    if (role == null) {
      if (path != '/select-role') return '/select-role';
      return null;
    }
    final targetPath = role == 'owner' ? '/onboarding-owner' : '/onboarding-player';
    if (path != targetPath) return targetPath;
    return null;
  }

 // 4. User data loading check
 if (userModel == null) {
 if (authProvider.isLoading) {
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
 if (!userModel.isEmailVerified) {
 if (path != '/verify-email') return '/verify-email';
 return null;
 }
 
 if (userModel.isBlocked) {
 // FIX: Both Owner and Player blocked accounts go to /suspended
 // Previously owners were allowed to stay in /owner (security gap)
 if (path != '/suspended') return '/suspended';
 return null;
 }

  // 6. Admin / Co-Founder flow bypass
  if (authProvider.isAdmin) {
    if (path == '/welcome' ||
        path == '/splash' ||
        path == '/login' ||
        path.startsWith('/create-account') ||
        path.startsWith('/signup') ||
        path == '/onboarding-player' ||
        path == '/onboarding-owner') {
      return '/';
    }
    return null;
  }

  // 7. Registration detail check (missing phone)
  final rawPhone = userModel.phone?.trim() ?? '';
  final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
  final bool hasPhone = rawPhone.isNotEmpty && digitsOnly.length >= 9 && digitsOnly.length <= 12;
  if (!hasPhone) {
    final role = authProvider.userType ?? userModel.role;
    final targetPath = role == 'owner' ? '/onboarding-owner' : '/onboarding-player';
    if (path != targetPath) return targetPath;
    return null;
  }

  // 8. Owner flow gating
 if (isOwner) {
 if (path.startsWith('/match/') || path.startsWith('/team/')) {
 return '/owner';
 }

  final bool isOnboardingConfirmed = userModel.isOnboardingConfirmed;
 
 if (!userModel.hasStadium && !isOnboardingConfirmed) {
 if (path != '/facility-onboarding') return '/facility-onboarding';
 return null;
 }

 if (path == '/facility-onboarding' || path == '/documentation') {
 return null;
 }

 // Direct access to Owner Dashboard allowed
 
 if (path == '/welcome' || path == '/splash' || path == '/login' || path.startsWith('/create-account') || path.startsWith('/signup') || path == '/onboarding-player' || path == '/onboarding-owner' || path == '/verify-email' || path == '/owner' || path == '/player' || path == '/offline') {
 return '/';
 }
 return null;
 }

 // 8. Player flow gating
 if (path == '/welcome' || path == '/splash' || path == '/login' || path.startsWith('/create-account') || path.startsWith('/signup') || path == '/onboarding-player' || path == '/onboarding-owner' || path == '/suspended' || path == '/verify-email' || path == '/player') {
 return '/';
 }

 return null;
 }
}
