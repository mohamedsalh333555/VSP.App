import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/logger_service.dart';
import '../../services/secure_storage_service.dart';
import 'auth_session_validator.dart';

/// Result packet from profile fetch and session auto-patching.
class UserDataFetchResult {
  final UserModel? userModel;
  final String? userType;
  final bool isGhostUser;
  final String? errorMessage;
  final bool dataFetchError;
  final bool shouldSignOut;

  const UserDataFetchResult({
    this.userModel,
    this.userType,
    this.isGhostUser = false,
    this.errorMessage,
    this.dataFetchError = false,
    this.shouldSignOut = false,
  });
}

/// Orchestrates fetching user profile data from Supabase, applying fallbacks and role/verification overrides.
class AuthUserDataFetcher {
  final SupabaseClient? _client;
  final UserRepository _userRepository;

  AuthUserDataFetcher({
    SupabaseClient? client,
    UserRepository? userRepository,
  })  : _client = client,
        _userRepository = userRepository ?? UserRepository();

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Fetches and patches user data from Supabase DB.
  Future<UserDataFetchResult> fetch({
    required User user,
    required String? currentUserType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingRole = await SecureStorageService.readSecure('pending_oauth_role') ??
          prefs.getString('pending_oauth_role');
      if (pendingRole != null && !const {'player', 'owner'}.contains(pendingRole)) {
        return const UserDataFetchResult(dataFetchError: true);
      }
      String? userType = pendingRole ?? currentUserType;

      Map<String, dynamic>? userData;
      int retries = 3;
      while (retries > 0) {
        userData = await _userRepository.getUserData(user.id);
        if (userData != null) break;
        retries--;
        if (retries > 0) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (userData == null) {
        // Only provision a missing profile during an explicit OAuth registration flow.
        // Normal session restore must fail closed so a transient DB/RLS error cannot
        // manufacture a new local profile or silently change account state.
        final isLoginOnly = prefs.getBool('pending_oauth_is_login_only') ?? false;
        final canProvisionOAuthRegistration = pendingRole != null && !isLoginOnly;

        if (canProvisionOAuthRegistration) {
          try {
            // Identity, verification and subscription state are decided by the
            // server. Never manufacture a usable local profile after failure.
            final response = await _supabase.rpc(
              'provision_registration_profile', params: {'p_role': pendingRole});
            if (response is! Map || response['success'] != true) {
              return const UserDataFetchResult(dataFetchError: true);
            }
            userData = await _userRepository.getUserData(user.id);
          } catch (e) {
            VSPLogger.w('OAuth profile provisioning failed (${e.runtimeType}).');
          }
          if (userData == null || userData['id'] != user.id) {
            return const UserDataFetchResult(dataFetchError: true);
          }
        } else {
          return const UserDataFetchResult(
            dataFetchError: true,
            errorMessage:
                'تعذر استرجاع بيانات حسابك. يرجى المحاولة مرة أخرى أو التواصل مع الدعم.',
          );
        }
      }

      final isLoginOnly = prefs.getBool('pending_oauth_is_login_only') ?? false;

      if (AuthSessionValidator.isUnregisteredSocialLoginAttempt(
        isLoginOnly: isLoginOnly,
        userData: userData,
      )) {
        VSPLogger.w('Unregistered social account requires onboarding.');
        await prefs.remove('pending_oauth_is_login_only');
        return const UserDataFetchResult(
          shouldSignOut: false,
          isGhostUser: true,
          errorMessage: null,
        );
      }

      await prefs.remove('pending_oauth_is_login_only');

      if (userData.isNotEmpty) {
        final effectiveRole = pendingRole ?? userType;

        if (AuthSessionValidator.shouldOverrideOAuthRole(
          pendingRole: effectiveRole,
          userData: userData,
        )) {
          final updated = await _userRepository.setUserRole(user.id, effectiveRole!);
          if (!updated) {
            return const UserDataFetchResult(dataFetchError: true);
          }
          final authoritative = await _userRepository.getUserData(user.id);
          if (authoritative == null || authoritative['id'] != user.id ||
              authoritative['role'] != effectiveRole) {
            return const UserDataFetchResult(dataFetchError: true);
          }
          userData = authoritative;
          try {
            await _supabase.auth.updateUser(UserAttributes(data: {'role': effectiveRole}));
          } catch (_) {}
          userType = effectiveRole;
          await prefs.remove('pending_oauth_role');
          await SecureStorageService.deleteSecure('pending_oauth_role');
        }

        final bool isExistingCompleteUser = AuthSessionValidator.isExistingCompleteUser(userData);
        if (isExistingCompleteUser) {
          userType = null;
          await prefs.remove('pending_oauth_role');
          await SecureStorageService.deleteSecure('pending_oauth_role');
        }

        var userModel = UserModel.fromFirestore(userData);

        if (AuthSessionValidator.needsEmailVerificationSync(
          authUser: user,
          userModel: userModel,
        )) {
          userModel = userModel.copyWith(isEmailVerified: true);
          await _userRepository.updateUserProfile(
            user.id,
            {'is_email_verified': true},
            authUser: user,
            role: userData['role']?.toString(),
          );
        }

        if (AuthSessionValidator.shouldAutoPatchRegistrationComplete(userModel)) {
          final completed = await _userRepository.updateUserProfile(
            user.id,
            {'isRegistrationComplete': true},
            authUser: user,
            role: userData['role']?.toString(),
          );
          if (completed) {
            final authoritative = await _userRepository.getUserData(user.id);
            if (authoritative == null || authoritative['id'] != user.id) {
              return const UserDataFetchResult(dataFetchError: true);
            }
            userModel = UserModel.fromFirestore(authoritative);
          }
        }

        if (AuthSessionValidator.shouldClearUserTypeForAutoLogin(userModel)) {
          userType = null;
        }

        return UserDataFetchResult(
          userModel: userModel,
          userType: userType,
          isGhostUser: false,
          dataFetchError: false,
        );
      } else {
        return const UserDataFetchResult(
          isGhostUser: true,
          errorMessage: 'تعذر استرجاع بيانات حسابك. يرجى المحاولة مرة أخرى أو التواصل مع الدعم.',
        );
      }
    } catch (e) {
      VSPLogger.w('Account profile fetch failed (${e.runtimeType}).');
      return const UserDataFetchResult(dataFetchError: true);
    }
  }

  /// Retries fetching user profile data when previous attempt failed.
  Future<UserDataFetchResult> retryDataFetch(String uid) async {
    try {
      final userData = await _userRepository.getUserData(uid);
      if (userData != null) {
        return UserDataFetchResult(userModel: UserModel.fromFirestore(userData));
      }
      return const UserDataFetchResult(dataFetchError: true);
    } catch (_) {
      return const UserDataFetchResult(dataFetchError: true);
    }
  }

  /// Silently update FCM push token for user in Supabase.
  Future<void> updateFcmToken(String uid, String? token) async {
    if (token == null) return;
    try {
      await _supabase.from('users').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {}
  }
}
