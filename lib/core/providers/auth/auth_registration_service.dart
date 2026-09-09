import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/logger_service.dart';
import '../../utils/phone_utils.dart';

/// Coordinates email/password authentication, account creation, and owner registration verification.
class AuthRegistrationService {
  final SupabaseClient? _client;
  final AuthService _authService;
  final UserRepository _userRepository;

  AuthRegistrationService({
    SupabaseClient? client,
    AuthService? authService,
    UserRepository? userRepository,
  })  : _client = client,
        _authService = authService ?? AuthService(),
        _userRepository = userRepository ?? UserRepository();

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Sign up with email, password, and initial user data.
  Future<({bool success, User? user, UserModel? userModel, String? error})> signUp({
    required String email,
    required String password,
    required String role,
    required String governorate,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final result = await _authService.signUpWithEmail(
        email: email,
        password: password,
        role: role,
        userData: {
          ...userData ?? {},
          'governorate': governorate,
        },
      );

      if (result['success'] == true) {
        final firebaseUser = result['user'] as User?;
        if (firebaseUser == null) {
          return (success: false, user: null, userModel: null, error: 'User registration failed');
        }

        final profileData = {
          'name': userData?['name'],
          'phone': userData?['phone'],
          'position': userData?['position'] ?? 'GK',
          'governorate': userData?['governorate'] ?? governorate,
          'date_of_birth': userData?['date_of_birth'],
          'is_registration_complete': true,
          'is_email_verified': true,
        };

        await _userRepository.completeRegistrationFlags(firebaseUser.id, profileData);

        UserModel? userModel;
        final existingData = await _userRepository.getUserData(firebaseUser.id);
        if (existingData != null) {
          userModel = UserModel.fromFirestore(existingData);
          if (!userModel.isRegistrationComplete) {
            userModel = userModel.copyWith(isRegistrationComplete: true);
          }
        } else {
          userModel = UserModel(
            uid: firebaseUser.id,
            email: email,
            role: role,
            name: userData?['name'],
            phone: userData?['phone'],
            position: userData?['position'] ?? 'GK',
            governorate: userData?['governorate'] ?? governorate,
            isRegistrationComplete: true,
            isEmailVerified: true,
            dateOfBirth: userData?['date_of_birth'] != null
                ? DateTime.tryParse(userData!['date_of_birth'])
                : null,
          );
        }

        return (success: true, user: firebaseUser, userModel: userModel, error: null);
      } else {
        return (success: false, user: null, userModel: null, error: result['message']?.toString());
      }
    } catch (e) {
      return (success: false, user: null, userModel: null, error: e.toString());
    }
  }

  /// Sign in with email and password.
  Future<({bool success, User? user, UserModel? userModel, String? error})> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        final firebaseUser = result['user'] as User?;
        if (firebaseUser == null) {
          return (success: false, user: null, userModel: null, error: 'Sign in returned null user');
        }

        final userData = await _userRepository.getUserData(firebaseUser.id);
        UserModel userModel;
        if (userData != null) {
          userModel = UserModel.fromFirestore(userData);
          if (!userModel.isRegistrationComplete) {
            userModel = userModel.copyWith(isRegistrationComplete: true);
            await _userRepository.updateUserProfile(
              firebaseUser.id,
              {'isRegistrationComplete': true},
              authUser: firebaseUser,
              role: userData['role'] ?? userModel.role,
            );
          }
        } else {
          userModel = UserModel(
            uid: firebaseUser.id,
            email: email,
            role: 'player',
          );
        }

        return (success: true, user: firebaseUser, userModel: userModel, error: null);
      } else {
        return (success: false, user: null, userModel: null, error: result['message']?.toString());
      }
    } catch (e) {
      return (success: false, user: null, userModel: null, error: e.toString());
    }
  }

  /// Finalize account creation / Update password and profile completion flags.
  Future<({bool success, UserModel? userModel, String? error})> createAccount({
    required User? currentUser,
    required UserModel? currentUserModel,
    required String? password,
    required String? name,
    required String? phone,
    required String? position,
    required String? userType,
  }) async {
    final user = currentUser ?? _authService.currentUser;
    if (user == null) {
      return (
        success: false,
        userModel: null,
        error: 'جلسة المستخدم غير صالحة، يرجى إعادة تسجيل الدخول.'
      );
    }

    try {
      if (password != null && password.isNotEmpty) {
        final pwSuccess = await _authService.updatePassword(password);
        if (!pwSuccess) {
          return (
            success: false,
            userModel: null,
            error: 'Failed to update password. Please try again.'
          );
        }
      }

      final success = await _userRepository.updateUserProfile(
        user.id,
        {
          'name': name,
          'phone': PhoneUtils.normalize(phone ?? ''),
          'position': position,
          'isRegistrationComplete': true,
        },
        authUser: user,
        role: userType ?? currentUserModel?.role,
      );

      UserModel? updatedModel = currentUserModel;
      if (success && currentUserModel != null) {
        updatedModel = currentUserModel.copyWith(isRegistrationComplete: true);
      }

      return (success: success, userModel: updatedModel, error: null);
    } catch (e) {
      return (success: false, userModel: null, error: e.toString());
    }
  }

  /// Trusted method — completes owner onboarding registration.
  Future<({bool success, UserModel? userModel})> completeOwnerRegistration({
    required User? authUser,
    required UserModel? currentUserModel,
    required String verificationStatus,
  }) async {
    if (authUser == null || currentUserModel == null) {
      return (success: false, userModel: null);
    }

    try {
      Map<String, dynamic> updatedAdditional;
      if (currentUserModel.additionalData != null && currentUserModel.additionalData!.isNotEmpty) {
        try {
          final jsonStr = jsonEncode(currentUserModel.additionalData);
          updatedAdditional = Map<String, dynamic>.from(jsonDecode(jsonStr));
        } catch (_) {
          updatedAdditional = Map<String, dynamic>.from(currentUserModel.additionalData!);
        }
      } else {
        updatedAdditional = {};
      }
      updatedAdditional['isOnboardingConfirmed'] = true;

      try {
        await _supabase.rpc('submit_owner_verification', params: {
          'p_owner_id': authUser.id,
          'p_additional_data': updatedAdditional,
        });
      } catch (rpcErr) {
        VSPLogger.w('RPC submit_owner_verification fallback: $rpcErr');
        await _supabase.from('users').update({
          'verification_status': verificationStatus,
          'is_registration_complete': true,
          'has_stadium': true,
          'additional_data': updatedAdditional,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', authUser.id);
      }

      final updatedModel = currentUserModel.copyWith(
        verificationStatus: verificationStatus,
        isRegistrationComplete: true,
        hasStadium: true,
        additionalData: updatedAdditional,
      );

      return (success: true, userModel: updatedModel);
    } catch (e) {
      VSPLogger.e('completeOwnerRegistration failed', e);
      return (success: false, userModel: null);
    }
  }

  /// Aborts uncompleted registration and purges the row.
  Future<void> abortRegistration(User? authUser, UserModel? userModel) async {
    final uid = authUser?.id;
    if (uid != null) {
      if (userModel?.isRegistrationComplete != true) {
        try {
          await _supabase.rpc('delete_user_permanently', params: {'p_user_id': uid});
          VSPLogger.i('abortRegistration: Incomplete account purged for UID: $uid');
        } catch (e) {
          VSPLogger.w('abortRegistration RPC error: $e');
          try {
            await _authService.deleteAccount(uid);
          } catch (_) {}
        }
      } else {
        VSPLogger.w('abortRegistration called on a completed account.');
      }
    }
  }

  /// Verify OTP token via Supabase Auth
  Future<bool> verifyOtp({required String email, required String token}) async {
    return _authService.verifyOtp(email: email, token: token);
  }

  /// Resend OTP email verification
  Future<bool> resendOtp() async {
    return _authService.sendEmailVerification();
  }

  /// Password reset email
  Future<bool> resetPassword(String email) async {
    return _authService.sendPasswordResetEmail(email);
  }
}
