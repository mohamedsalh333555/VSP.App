import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/logger_service.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/phone_utils.dart';

/// Coordinates social OAuth logins (Google & Apple) and subsequent profile completion.
class AuthOAuthCoordinator {
  final SupabaseClient? _client;
  final AuthService _authService;
  final UserRepository _userRepository;

  AuthOAuthCoordinator({
    SupabaseClient? client,
    AuthService? authService,
    UserRepository? userRepository,
  })  : _client = client,
        _authService = authService ?? AuthService(),
        _userRepository = userRepository ?? UserRepository();

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Initiate sign in with Google OAuth flow.
  Future<({bool success, User? user, String? error})> signInWithGoogle({
    required bool isLoginOnly,
    required String? userType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_oauth_is_login_only', isLoginOnly);
      await prefs.setString('pending_oauth_role', userType ?? 'player');
      await SecureStorageService.writeSecure('pending_oauth_role', userType ?? 'player');

      final result = await _authService.signInWithGoogle(role: userType);

      if (result['success'] == true) {
        final returnedUser = result['user'] as User?;
        return (success: true, user: returnedUser, error: null);
      } else {
        return (success: false, user: null, error: result['message']?.toString());
      }
    } catch (e) {
      return (success: false, user: null, error: e.toString());
    }
  }

  /// Initiate sign in with Apple OAuth flow.
  Future<({bool success, User? user, String? error})> signInWithApple({
    required bool isLoginOnly,
    required String? userType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_oauth_is_login_only', isLoginOnly);
      await prefs.setString('pending_oauth_role', userType ?? 'player');
      await SecureStorageService.writeSecure('pending_oauth_role', userType ?? 'player');

      final result = await _authService.signInWithApple(role: userType);

      if (result['success'] == true) {
        final returnedUser = result['user'] as User?;
        return (success: true, user: returnedUser, error: null);
      } else {
        return (success: false, user: null, error: result['message']?.toString());
      }
    } catch (e) {
      return (success: false, user: null, error: e.toString());
    }
  }

  /// Completes social registration with phone, name, and role details.
  Future<({bool success, UserModel? userModel, String? error})> completeSocialRegistration({
    required User? firebaseUser,
    required UserModel? currentUserModel,
    required String? userType,
    required String fallbackGovernorate,
    required String phone,
    String? name,
    String? position,
    String? governorate,
    DateTime? dateOfBirth,
    String? p2pInstapay,
    String? p2pVodafone,
    String? p2pBank,
  }) async {
    final currentUid = firebaseUser?.id;
    final normalizedPhone = PhoneUtils.normalize(phone) ?? phone;
    UserModel? existingPhoneUser;
    try {
      existingPhoneUser = await _userRepository
          .getUserByPhone(normalizedPhone)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      VSPLogger.w('getUserByPhone timeout or error in completeSocialRegistration: $e');
    }

    if (existingPhoneUser != null && existingPhoneUser.uid != currentUid) {
      return (
        success: false,
        userModel: null,
        error: 'هذا الرقم مسجل مسبقاً، يرجى استخدام رقم آخر.'
      );
    }

    try {
      final Map<String, dynamic> updateData = {
        'phone': normalizedPhone,
        'governorate': governorate ?? fallbackGovernorate,
        'isRegistrationComplete': true,
        'date_of_birth': dateOfBirth?.toUtc().toIso8601String(),
        'p2p_instapay': p2pInstapay,
        'p2p_vodafone': p2pVodafone,
        'p2p_bank': p2pBank,
      };
      if (name != null && name.isNotEmpty) {
        updateData['name'] = name;
      }
      if (position != null) {
        updateData['position'] = position;
      }

      final effectiveRole = userType ?? currentUserModel?.role ?? 'player';

      UserModel updatedModel;
      if (currentUserModel != null) {
        updatedModel = currentUserModel.copyWith(
          name: (name != null && name.isNotEmpty) ? name : currentUserModel.name,
          phone: normalizedPhone,
          governorate: governorate ?? fallbackGovernorate,
          position: position ?? currentUserModel.position,
          isRegistrationComplete: true,
          isEmailVerified: true,
          dateOfBirth: dateOfBirth ?? currentUserModel.dateOfBirth,
          p2pInstapay: p2pInstapay ?? currentUserModel.p2pInstapay,
          p2pVodafone: p2pVodafone ?? currentUserModel.p2pVodafone,
          p2pBank: p2pBank ?? currentUserModel.p2pBank,
        );
      } else {
        updatedModel = UserModel(
          uid: currentUid ?? firebaseUser?.id ?? '',
          email: firebaseUser?.email ?? '',
          role: effectiveRole,
          name: (name != null && name.isNotEmpty)
              ? name
              : (firebaseUser?.userMetadata?['full_name'] ??
                  firebaseUser?.userMetadata?['name'] ??
                  (effectiveRole == 'owner' ? 'مالك جديد' : 'لاعب جديد')),
          phone: normalizedPhone,
          governorate: governorate ?? fallbackGovernorate,
          position: position,
          dateOfBirth: dateOfBirth,
          p2pInstapay: p2pInstapay,
          p2pVodafone: p2pVodafone,
          p2pBank: p2pBank,
          isRegistrationComplete: true,
          isEmailVerified: true,
          hasStadium: false,
          isIdentityVerified: false,
          verificationStatus: 'pending',
          subscriptionPlan: 'free_trial',
          trialEndsAt: DateTime.now().add(const Duration(days: 365)),
        );
      }

      try {
        final dynamic rpcRes = await _supabase.rpc('complete_user_registration', params: {
          'p_user_id': currentUid,
          'p_phone': normalizedPhone,
          'p_name': (name != null && name.isNotEmpty) ? name : updatedModel.name,
          'p_position': position,
          'p_governorate': governorate ?? fallbackGovernorate,
          'p_date_of_birth': dateOfBirth?.toUtc().toIso8601String(),
          'p_p2p_instapay': p2pInstapay,
          'p_p2p_vodafone': p2pVodafone,
          'p_p2p_bank': p2pBank,
        }).timeout(const Duration(seconds: 10));

        if (rpcRes is Map && rpcRes['success'] == false) {
          VSPLogger.w('RPC complete_user_registration returned failure: ${rpcRes['error']}');
          if (currentUid != null) {
            await _userRepository.completeRegistrationFlags(currentUid, updateData);
          }
        }
      } catch (rpcErr) {
        VSPLogger.w('RPC complete_user_registration fallback: $rpcErr');
        if (currentUid != null) {
          await _userRepository.completeRegistrationFlags(currentUid, updateData);
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_oauth_role');
        await SecureStorageService.deleteSecure('pending_oauth_role');
      } catch (_) {}

      return (success: true, userModel: updatedModel, error: null);
    } catch (e) {
      return (success: false, userModel: null, error: e.toString());
    }
  }
}
