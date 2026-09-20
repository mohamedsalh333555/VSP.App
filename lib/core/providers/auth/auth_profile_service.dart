import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/logger_service.dart';
import '../../services/storage_service.dart';
import '../../utils/phone_utils.dart';

/// Handles profile updates, photo uploads, GPS location sync, and account deletion.
class AuthProfileService {
  final SupabaseClient? _client;
  final AuthService? _authService;
  final StorageService? _storageService;
  final LocationService? _locationService;
  final UserRepository? _userRepository;

  AuthProfileService({
    SupabaseClient? client,
    AuthService? authService,
    StorageService? storageService,
    LocationService? locationService,
    UserRepository? userRepository,
  })  : _client = client,
        _authService = authService,
        _storageService = storageService,
        _locationService = locationService,
        _userRepository = userRepository;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  AuthService get _auth => _authService ?? AuthService();
  StorageService get _storage => _storageService ?? StorageService();
  LocationService get _location => _locationService ?? LocationService();
  UserRepository get _userRepo => _userRepository ?? UserRepository();

  /// Update user password.
  Future<bool> updatePassword(String newPassword) async {
    return _auth.updatePassword(newPassword);
  }

  /// Sanitizes profile update data against restricted and security-sensitive fields.
  static Map<String, dynamic> sanitizeProfileData(Map<String, dynamic> data) {
    final sanitizedData = Map<String, dynamic>.from(data);
    const restrictedFields = [
      'role',
      'points',
      'walletBalance',
      'wallet_balance',
      'isVerified',
      'is_verified',
      'isEmailVerified',
      'is_email_verified',
      'lastSeen',
      'last_seen',
      'fcmToken',
      'fcm_token',
      'isBlocked',
      'is_blocked',
      'noShowCount',
      'no_show_count',
      'isIdentityVerified',
      'is_identity_verified',
      'verificationStatus',
      'verification_status',
      'hasStadium',
      'has_stadium',
      'isRegistrationComplete',
      'is_registration_complete',
    ];
    for (var field in restrictedFields) {
      sanitizedData.remove(field);
    }
    if (sanitizedData.containsKey('phone')) {
      sanitizedData['phone'] = PhoneUtils.normalize(sanitizedData['phone'] ?? '');
    }
    return sanitizedData;
  }

  /// Updates user profile record in database and returns the updated UserModel.
  Future<({bool success, UserModel? updatedModel, String? error})> updateProfile({
    required User? authUser,
    required UserModel? currentUserModel,
    required String? userType,
    required Map<String, dynamic> data,
  }) async {
    if (authUser == null) return (success: false, updatedModel: null, error: 'No auth user');

    final sanitizedData = sanitizeProfileData(data);
    if (sanitizedData.isEmpty) {
      return (success: true, updatedModel: currentUserModel, error: null);
    }

    try {
      final success = await _userRepo.updateUserProfile(
        authUser.id,
        sanitizedData,
        authUser: authUser,
        role: currentUserModel?.role ?? userType,
      );

      UserModel? updatedModel = currentUserModel;
      if (success && currentUserModel != null) {
        updatedModel = currentUserModel.copyWith(
          name: sanitizedData['name'] ?? currentUserModel.name,
          phone: sanitizedData['phone'] ?? currentUserModel.phone,
          profileImageUrl: sanitizedData['profile_image_url'] ??
              sanitizedData['profileImageUrl'] ??
              currentUserModel.profileImageUrl,
          position: sanitizedData['position'] ?? currentUserModel.position,
          hasStadium: sanitizedData['hasStadium'] ?? currentUserModel.hasStadium,
          isRegistrationComplete: sanitizedData['isRegistrationComplete'] ??
              currentUserModel.isRegistrationComplete,
          isIdentityVerified: sanitizedData['isIdentityVerified'] ??
              currentUserModel.isIdentityVerified,
          governorate: sanitizedData['governorate'] ?? currentUserModel.governorate,
          favoriteStadiums: sanitizedData['favorite_stadiums'] ??
              sanitizedData['favoriteStadiums'] ??
              currentUserModel.favoriteStadiums,
          verificationStatus: sanitizedData['verificationStatus'] ??
              currentUserModel.verificationStatus,
          dateOfBirth: sanitizedData['date_of_birth'] != null
              ? DateTime.tryParse(sanitizedData['date_of_birth'])
              : (sanitizedData['dateOfBirth'] ?? currentUserModel.dateOfBirth),
          p2pInstapay: sanitizedData['p2p_instapay'] ??
              sanitizedData['p2pInstapay'] ??
              currentUserModel.p2pInstapay,
          p2pVodafone: sanitizedData['p2p_vodafone'] ??
              sanitizedData['p2pVodafone'] ??
              currentUserModel.p2pVodafone,
          p2pBank: sanitizedData['p2p_bank'] ??
              sanitizedData['p2pBank'] ??
              currentUserModel.p2pBank,
          additionalData: sanitizedData['additionalData'] ??
              sanitizedData['additional_data'] ??
              currentUserModel.additionalData,
        );
      }

      return (success: success, updatedModel: updatedModel, error: null);
    } catch (e) {
      debugPrint('Profile update error masked for security.');
      return (success: false, updatedModel: null, error: e.toString());
    }
  }

  /// Uploads user profile photo to Supabase storage.
  Future<({bool success, String? imageUrl, String? error})> uploadProfilePhoto({
    required User? authUser,
    required UserModel? currentUserModel,
    required XFile file,
  }) async {
    if (authUser == null) return (success: false, imageUrl: null, error: 'User not authenticated');

    try {
      final uid = authUser.id;
      final oldUrl = currentUserModel?.profileImageUrl;

      String? url;
      if (kIsWeb) {
        url = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150';
      } else {
        url = await _storage.uploadProfilePicture(
          file: file,
          userId: uid,
          oldImageUrl: oldUrl,
        );
      }
      if (url == null) throw 'Upload returned null';

      return (success: true, imageUrl: url, error: null);
    } catch (e) {
      return (success: false, imageUrl: null, error: 'Failed to upload profile image: $e');
    }
  }

  /// Toggles favorite stadium id in user profile.
  List<String> toggleFavoriteStadiumList({
    required List<String> currentFavorites,
    required String stadiumId,
  }) {
    final updatedList = List<String>.from(currentFavorites);
    if (updatedList.contains(stadiumId)) {
      updatedList.remove(stadiumId);
    } else {
      updatedList.add(stadiumId);
    }
    return updatedList;
  }

  /// Determines current Egyptian governorate via GPS.
  Future<({Position? position, String? governorate, String? error})> determineGPSGovernorate({
    bool force = false,
  }) async {
    final result = await _location.getThrottledLocation(force: force);
    if (result.$2 == 'mock_location_detected') {
      return (
        position: result.$1,
        governorate: null,
        error:
            'تنبيه الأمان: تم اكتشاف محاولة لتزييف الموقع الجغرافي (Mock Location). يرجى إيقاف برامج تزييف الموقع للمتابعة.'
      );
    }
    return (position: result.$1, governorate: result.$2, error: null);
  }

  /// Call RPC to pay rehabilitation fine and clear blocked status.
  Future<bool> payRehabilitationFine(String uid) async {
    try {
      final response = await _supabase.rpc(
        'pay_rehabilitation_fine',
        params: {'p_user_id': uid},
      );
      return response == true;
    } catch (e) {
      VSPLogger.e('Error paying rehabilitation fine', e);
      return false;
    }
  }

  /// Deletes the authenticated account through the server-side atomic deletion RPC.
  /// No client-side Auth fallback is allowed because it can leave partial data behind.
  Future<({bool success, String? error})> deleteAccount(UserModel userModel) async {
    try {
      final response = await _supabase.rpc(
        'delete_user_permanently',
        params: {'p_user_id': userModel.uid},
      );

      final data = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      final success = data['success'] == true;
      if (!success) {
        return (
          success: false,
          error: data['message']?.toString() ?? 'تعذر حذف الحساب بالكامل.',
        );
      }

      await _auth.signOut();
      return (success: true, error: null);
    } catch (e) {
      return (
        success: false,
        error: 'حدث خطأ أثناء محاولة حذف الحساب. لم يتم اعتماد الحذف.',
      );
    }
  }

}