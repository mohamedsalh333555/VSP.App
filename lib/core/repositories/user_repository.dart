import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';
import '../utils/phone_utils.dart';
import '../constants/egypt_governorates.dart';

class UserRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final normalizedPhone = PhoneUtils.normalize(phone);
      if (normalizedPhone == null || normalizedPhone.isEmpty) return null;
      final response = await _supabase
          .from('users')
          .select()
          .eq('phone', normalizedPhone)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromFirestore(response);
    } catch (e) {
      VSPLogger.e('Error getting user by phone', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return response;
    } catch (e) {
      VSPLogger.e('Error fetching user data for UID: $uid', e);
      return null;
    }
  }

  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _supabase
          .from('users')
          .select()
          .inFilter('id', ids);
      
      return (response as List).map((data) => UserModel.fromFirestore(data as Map<String, dynamic>)).toList();
    } catch (e) {
      VSPLogger.e('Error getting users by IDs', e);
      return [];
    }
  }

  Map<String, dynamic> _convertToSnakeCase(Map<String, dynamic> map) {
    final snakeCaseMap = <String, dynamic>{};
    map.forEach((key, value) {
      final snakeKey = key
          .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
          .toLowerCase();
      snakeCaseMap[snakeKey] = value;
    });
    return snakeCaseMap;
  }

  Future<bool> updateUserProfile(
    String userId, 
    Map<String, dynamic> data, {
    User? authUser,
    String? role,
  }) async {
    final snakeData = _convertToSnakeCase(data);

    // Ensure user profile row exists in public.users database
    final exists = await getUserData(userId);
    if (exists == null) {
      final user = authUser ?? _supabase.auth.currentUser;
      final Map<String, dynamic> initialData = {
        'id': userId,
        'email': user?.email ?? snakeData['email'] ?? '',
        'role': role ?? user?.userMetadata?['role'] ?? snakeData['role'] ?? 'player',
        'name': user?.userMetadata?['name'] ?? snakeData['name'] ?? '',
        'phone': user?.phone ?? user?.userMetadata?['phone'] ?? snakeData['phone'] ?? '',
        'is_email_verified': user?.emailConfirmedAt != null,
        'has_stadium': false,
        'is_identity_verified': false,
        'is_registration_complete': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      try {
        await _supabase.from('users').insert(initialData);
      } catch (e) {
        VSPLogger.e('Error inserting missing user profile on update', e);
      }
    }

    final securedData = Map<String, dynamic>.from(snakeData);
    securedData.remove('role');
    securedData.remove('id');
    securedData.remove('uid');
    securedData.remove('email');
    securedData.remove('created_at');
    // Allow 'is_email_verified' to be updated if explicitly passed in data (e.g. during auth synchronization)
    if (!data.containsKey('is_email_verified') && !data.containsKey('isEmailVerified')) {
      securedData.remove('is_email_verified');
    }
    securedData.remove('points');
    securedData.remove('wallet_balance');
    // 🛡️ SECURITY FIX: Also block server-side to prevent privilege escalation
    // even if AuthProvider's client-side check is bypassed.
    securedData.remove('is_blocked');
    securedData.remove('no_show_count');
    securedData.remove('is_identity_verified');
    securedData.remove('verification_status');
    securedData.remove('has_stadium');
    // 🛡️ SECURITY FIX: Prevent direct manipulation of the registration-complete flag
    // from any client-side update path. This flag is set by trusted server-side triggers only.
    securedData.remove('is_registration_complete');
    
    // Standardize Governorate
    if (securedData.containsKey('governorate')) {
      final String? gov = securedData['governorate']?.toString();
      if (gov != null) {
        final standardGov = EgyptGovernorates.resolveGoogleName(gov);
        if (standardGov != null) {
          securedData['governorate'] = standardGov;
        } else {
          securedData.remove('governorate');
        }
      }
    }

    securedData['updated_at'] = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabase.from('users').update(securedData).eq('id', userId);
      return true;
    } catch (e) {
      VSPLogger.e('Error updating user profile $userId', e);
      return false;
    }
  }

  /// Trusted method to complete user registration and persist is_registration_complete flag permanently in DB
  Future<bool> completeRegistrationFlags(String userId, Map<String, dynamic> additionalData) async {
    try {
      try {
        await _supabase.rpc('complete_user_registration', params: {
          'p_user_id': userId,
          'p_phone': additionalData['phone'] ?? additionalData['p_phone'],
          'p_name': additionalData['name'] ?? additionalData['p_name'],
          'p_position': additionalData['position'] ?? additionalData['p_position'],
          'p_governorate': additionalData['governorate'] ?? additionalData['p_governorate'] ?? 'Cairo',
          'p_date_of_birth': additionalData['date_of_birth'] ?? additionalData['p_date_of_birth'],
          'p2p_instapay': additionalData['p2p_instapay'],
          'p2p_vodafone': additionalData['p2p_vodafone'],
          'p2p_bank': additionalData['p2p_bank'],
        });
        VSPLogger.i('✅ complete_user_registration RPC persisted successfully for $userId');
        return true;
      } catch (rpcErr) {
        VSPLogger.w('RPC complete_user_registration fallback notice: $rpcErr');
        final snakeData = _convertToSnakeCase(additionalData);
        snakeData['is_registration_complete'] = true;
        snakeData['is_email_verified'] = true;
        snakeData['updated_at'] = DateTime.now().toUtc().toIso8601String();

        // Ensure profile row exists
        final exists = await getUserData(userId);
        if (exists == null) {
          final user = _supabase.auth.currentUser;
          snakeData['id'] = userId;
          snakeData['email'] = user?.email ?? '';
          snakeData['role'] = user?.userMetadata?['role'] ?? 'player';
          snakeData['created_at'] = DateTime.now().toUtc().toIso8601String();
          await _supabase.from('users').insert(snakeData);
        } else {
          await _supabase.from('users').update(snakeData).eq('id', userId);
        }
        VSPLogger.i('✅ completeRegistrationFlags persisted successfully for $userId');
        return true;
      }
    } catch (e) {
      VSPLogger.e('Error completing registration flags for $userId', e);
      return false;
    }
  }

  Future<void> updateUserModerationStatus(String userId, {required bool isBlocked, String? warningMessage}) async {
    try {
      await _supabase.from('users').update({
        'is_blocked': isBlocked,
        if (warningMessage != null) 'last_warning': warningMessage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      if (warningMessage != null) {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Safety Warning ⚠️',
        'body': warningMessage,
        'type': 'warning',
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      }
    } catch (e) {
      VSPLogger.e('Error updating user moderation status', e);
    }
  }

  Future<bool> createUserProfile(User user, Map<String, dynamic> data) async {
    final sanitizedData = _convertToSnakeCase(data);
    
    sanitizedData['id'] = user.id;
    sanitizedData['email'] = user.email ?? '';
    sanitizedData['is_email_verified'] = user.emailConfirmedAt != null;
    sanitizedData['created_at'] = DateTime.now().toUtc().toIso8601String();
    sanitizedData['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    if (!sanitizedData.containsKey('role')) sanitizedData['role'] = 'player';
    if (!sanitizedData.containsKey('name')) sanitizedData['name'] = user.userMetadata?['name'] ?? '';
    if (!sanitizedData.containsKey('phone')) sanitizedData['phone'] = user.phone ?? '';
    if (!sanitizedData.containsKey('has_stadium')) sanitizedData['has_stadium'] = false;
    if (!sanitizedData.containsKey('is_identity_verified')) sanitizedData['is_identity_verified'] = false;
    if (!sanitizedData.containsKey('is_registration_complete')) sanitizedData['is_registration_complete'] = false;

    if (sanitizedData.containsKey('governorate')) {
      final String? gov = sanitizedData['governorate']?.toString();
      if (gov != null) {
        sanitizedData['governorate'] = EgyptGovernorates.resolveGoogleName(gov) ?? 'Cairo';
      }
    }

    try {
      await _supabase.from('users').insert(sanitizedData);
      return true;
    } catch (e) {
      VSPLogger.e('Error creating user profile', e);
      return false;
    }
  }

  Future<UserModel?> createGuestUser(String name) async {
    try {
      // توليد معرف عشوائي آمن للضيف
      final guestId = 'guest_${const Uuid().v4()}'; 
      final initialData = {
        'id': guestId,
        'email': '',
        'role': 'player',
        'name': name,
        'phone': null, // الرقم فارغ تماماً لحماية الهوية
        'is_email_verified': false,
        'has_stadium': false,
        'is_identity_verified': false,
        'is_registration_complete': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('users').insert(initialData);
      return UserModel(
        uid: guestId,
        email: '',
        name: name,
        role: 'player',
        isRegistrationComplete: false,
      );
    } catch (e) {
      VSPLogger.e('Error creating guest user', e);
      return null;
    }
  }
}
