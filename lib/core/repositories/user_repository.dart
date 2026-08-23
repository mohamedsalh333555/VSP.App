import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';
import '../constants/egypt_governorates.dart';
import '../utils/phone_utils.dart';

class UserRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      final cleanPhone = phone.trim();
      if (cleanPhone.isEmpty) return null;
      final response = await _supabase
          .from('users')
          .select()
          .eq('phone', cleanPhone)
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

    final securedData = Map<String, dynamic>.from(snakeData);
    // 🛡️ Client-side sanitation complementing server-side security triggers
    const restrictedKeys = [
      'role',
      'id',
      'uid',
      'email',
      'created_at',
      'points',
      'wallet_balance',
      'is_blocked',
      'no_show_count',
      'is_identity_verified',
      'verification_status',
      'has_stadium',
      'is_registration_complete',
      'subscription_plan',
      'trial_ends_at',
      'subscription_expires_at',
      'total_platform_fees',
      'cash_booking_banned',
    ];
    
    for (final key in restrictedKeys) {
      securedData.remove(key);
    }
    
    if (!data.containsKey('is_email_verified') && !data.containsKey('isEmailVerified')) {
      securedData.remove('is_email_verified');
    }
    
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

    if (securedData.containsKey('phone')) {
      securedData['phone'] = PhoneUtils.normalize(securedData['phone']?.toString());
    }

    securedData['updated_at'] = DateTime.now().toUtc().toIso8601String();

    if (securedData.isEmpty) return true;

    try {
      await _supabase.from('users').update(securedData).eq('id', userId);
      return true;
    } catch (e) {
      VSPLogger.e('Error updating user profile $userId', e);
      return false;
    }
  }

  /// Securely set user role on signup via dedicated RPC set_user_role_on_signup
  Future<bool> setUserRole(String userId, String role) async {
    try {
      await _supabase.rpc('set_user_role_on_signup', params: {
        'p_user_id': userId,
        'p_role': role,
      });
      VSPLogger.i('✅ setUserRole persisted successfully for $userId with role: $role');
      return true;
    } catch (e) {
      VSPLogger.e('Error setting user role via RPC for $userId', e);
      return false;
    }
  }

  /// Trusted method to complete user registration via RPC complete_user_registration
  Future<bool> completeRegistrationFlags(String userId, Map<String, dynamic> additionalData) async {
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
    } catch (e) {
      VSPLogger.e('RPC complete_user_registration failed for $userId', e);
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
}
