import '../../services/auth_service.dart';
import 'auth_account_coordinator.dart';
import 'auth_location_coordinator.dart';
import 'auth_otp_service.dart';
import 'auth_profile_coordinator.dart';
import 'auth_profile_service.dart';
import 'auth_realtime_coordinator.dart';
import 'auth_session_sync_coordinator.dart';

/// Aggregates all domain coordinators for [AuthProvider].
class AuthCoordinators {
  final AuthAccountCoordinator account;
  final AuthProfileService profileService;
  final AuthRealtimeCoordinator realtime;
  final AuthSessionSyncCoordinator sessionSync;
  final AuthOtpService otp;
  final AuthLocationCoordinator location;
  final AuthProfileCoordinator profile;

  AuthCoordinators({
    AuthAccountCoordinator? account,
    AuthProfileService? profileService,
    AuthRealtimeCoordinator? realtime,
    AuthSessionSyncCoordinator? sessionSync,
    AuthOtpService? otp,
    AuthLocationCoordinator? location,
    AuthProfileCoordinator? profile,
    AuthService? authService,
  })  : account = account ?? AuthAccountCoordinator(),
        profileService = profileService ?? AuthProfileService(authService: authService ?? AuthService()),
        realtime = realtime ?? AuthRealtimeCoordinator(),
        sessionSync = sessionSync ?? AuthSessionSyncCoordinator(),
        otp = otp ?? AuthOtpService(),
        location = location ??
            AuthLocationCoordinator(
              profileService: profileService ?? AuthProfileService(authService: authService ?? AuthService()),
            ),
        profile = profile ??
            AuthProfileCoordinator(
              profileService: profileService ?? AuthProfileService(authService: authService ?? AuthService()),
            );
}
