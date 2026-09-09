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

  /// Deletes user account permanently, checking for active/upcoming bookings first.
  Future<({bool success, String? error})> deleteAccount(UserModel userModel) async {
    final uid = userModel.uid;
    final isOwner = userModel.role == 'owner';
    final now = DateTime.now();

    try {
      if (isOwner) {
        final stadiumRes = await _supabase
            .from('stadiums')
            .select('id')
            .eq('owner_id', uid);

        final stadiumIds = (stadiumRes as List).map((s) => s['id'].toString()).toList();

        if (stadiumIds.isNotEmpty) {
          final bookingsRes = await _supabase
              .from('bookings')
              .select('id, start_time, end_time, status')
              .inFilter('stadium_id', stadiumIds)
              .inFilter('status', ['confirmed', 'pending']);

          for (final b in bookingsRes as List) {
            final startStr = b['start_time']?.toString() ?? '';
            final bookingDt = DateTime.tryParse(startStr)?.toLocal() ?? _parseBookingDateTime('', startStr);
            if (bookingDt != null && bookingDt.isAfter(now.subtract(const Duration(hours: 2)))) {
              final diffMinutes = bookingDt.difference(now).inMinutes;
              if (diffMinutes <= 120 && diffMinutes >= -120) {
                return (
                  success: false,
                  error: 'لا يمكن حذف الحساب! يوجد حجز نشط في ملاعبك متبقي عليه أقل من ساعتين (أو جارٍ حالياً).'
                );
              } else {
                return (
                  success: false,
                  error: 'لا يمكن حذف الحساب! يوجد حجوزات قادمة مؤكدة في ملاعبك لم تكتمل بعد.'
                );
              }
            }
          }
        }
      } else {
        final bookingsRes = await _supabase
            .from('bookings')
            .select('id, start_time, end_time, status, joined_user_ids, created_by_user_id')
            .inFilter('status', ['confirmed', 'pending']);

        for (final b in bookingsRes as List) {
          final createdBy = b['created_by_user_id']?.toString() ?? '';
          final joinedUsers = List<String>.from(b['joined_user_ids'] ?? []);

          if (createdBy == uid || joinedUsers.contains(uid)) {
            final startStr = b['start_time']?.toString() ?? '';
            final bookingDt = DateTime.tryParse(startStr)?.toLocal() ?? _parseBookingDateTime('', startStr);

            if (bookingDt != null && bookingDt.isAfter(now.subtract(const Duration(hours: 2)))) {
              final diffMinutes = bookingDt.difference(now).inMinutes;
              if (diffMinutes <= 120 && diffMinutes >= -120) {
                return (
                  success: false,
                  error: 'لا يمكن حذف الحساب! لديك حجز مؤكد متبقي عليه أقل من ساعتين (أو جارٍ حالياً).'
                );
              } else {
                return (
                  success: false,
                  error: 'لا يمكن حذف الحساب! لديك حجز قادم لم يكتمل بعد.'
                );
              }
            }
          }
        }
      }

      try {
        await _supabase.rpc('delete_user_permanently', params: {'p_user_id': uid});
      } catch (rpcErr) {
        final fallbackRes = await _auth.deleteAccount(uid);
        if (fallbackRes['success'] != true) {
          return (success: false, error: fallbackRes['message']?.toString() ?? 'فشل حذف الحساب');
        }
      }

      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'حدث خطأ أثناء محاولة حذف الحساب: $e');
    }
  }

  DateTime? _parseBookingDateTime(String dateStr, String timeStr) {
    try {
      final parsedIso = DateTime.tryParse(dateStr);
      if (parsedIso != null) return parsedIso;

      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) return null;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      int hour = 0;
      int minute = 0;
      if (timeStr.isNotEmpty) {
        final timeParts = timeStr.split(':');
        if (timeParts.length >= 2) {
          hour = int.parse(timeParts[0]);
          minute = int.parse(timeParts[1].split(' ')[0]);
          if (timeStr.toLowerCase().contains('pm') && hour < 12) hour += 12;
          if (timeStr.toLowerCase().contains('am') && hour == 12) hour = 0;
        }
      }
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
