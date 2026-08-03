import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/phone_utils.dart';
import '../config/app_config.dart';
import 'logger_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _mockUser;

  // Get current user
  User? get currentUser => _mockUser ?? _supabase.auth.currentUser;

  // Stream of auth state changes mapped to User?
  Stream<User?> get authStateChanges => 
      _supabase.auth.onAuthStateChange.map((data) => _mockUser ?? data.session?.user);

  // Internal logger for security auditing
  void _logSecurityEvent(String event, dynamic error) {
    debugPrint('[SECURITY_LOG] $event: $error');
  }

  // Sign Up
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> userData,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (kDebugMode && AppConfig.useMockOtp) {
      final mockUserId = role == 'player' ? '8d3d7d65-a167-4138-b36c-85bbdead1b7a' : 'f64e7da9-6af7-47f2-9916-87cc7e6a1739';
      
      try {
        final existing = await _supabase.from('users').select('id').eq('id', mockUserId).maybeSingle();
        if (existing == null) {
          await _supabase.from('users').insert({
            'id': mockUserId,
            'email': cleanEmail,
            'role': role,
            'name': userData['name'] ?? 'Ahmed Player',
            'phone': PhoneUtils.normalize(userData['phone'] ?? '01033334444'),
            'is_email_verified': false,
            'is_registration_complete': false,
            'governorate': userData['governorate'] ?? 'Cairo',
            'position': userData['position'] ?? 'GK',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } else {
          await _supabase.from('users').update({
            'email': cleanEmail,
            'name': userData['name'] ?? 'Ahmed Player',
            'phone': PhoneUtils.normalize(userData['phone'] ?? '01033334444'),
            'is_email_verified': false,
            'is_registration_complete': false,
            'governorate': userData['governorate'] ?? 'Cairo',
            'position': userData['position'] ?? 'GK',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', mockUserId);
        }
      } catch (e) {
        VSPLogger.e("Mock user DB insertion error: $e");
      }

      final mockUser = User(
        id: mockUserId,
        email: cleanEmail,
        createdAt: DateTime.now().toIso8601String(),
        aud: 'authenticated',
        role: 'authenticated',
        appMetadata: {},
        userMetadata: {},
      );
      _mockUser = mockUser;
      VSPLogger.i('Mock Sign Up successful in debug mode for role: $role');
      return {'success': true, 'user': mockUser};
    }
    
    // Duplicate Email Check, Role Conflict Guard & Auto Login Fallback
    try {
      final emailCheck = await _supabase
          .from('users')
          .select('id, role')
          .eq('email', cleanEmail)
          .maybeSingle();

      if (emailCheck != null) {
        final existingRole = emailCheck['role']?.toString();

        // 🔴 Role conflict: same email registered under a different role
        if (existingRole != null && existingRole != role) {
          final arabicExistingRole = existingRole == 'player' ? 'لاعب' : 'مالك ملعب';
          return {
            'success': false,
            'message':
                'هذا البريد مسجل مسبقاً كـ $arabicExistingRole. '
                'يرجى تسجيل الدخول بحسابك أو استخدام بريد آخر.',
          };
        }

        // ✅ Same role — auto sign-in and return existing user directly to home
        try {
          final signInResponse = await _supabase.auth.signInWithPassword(
            email: cleanEmail,
            password: password,
          );
          if (signInResponse.user != null) {
            VSPLogger.i('Existing $role re-signed in automatically via signup flow: $cleanEmail');
            return {'success': true, 'user': signInResponse.user};
          }
        } catch (_) {
          // Wrong password for existing account
          return {
            'success': false,
            'message': 'البريد الإلكتروني مسجل بالفعل. تأكد من كلمة المرور الصحيحة أو سجّل دخولك.',
          };
        }
        return {'success': false, 'message': 'البريد الإلكتروني مسجل بالفعل.'};
      }
    } catch (e) {
      _logSecurityEvent('EMAIL_CHECK_FAILED', e);
    }
    
    // Duplicate Phone Check
    final rawPhone = userData['phone']?.toString() ?? '';
    final phone = PhoneUtils.normalize(rawPhone);
    if (await isPhoneRegistered(phone)) {
       return {'success': false, 'message': 'رقم الهاتف مسجل مسبقاً.'};
    }

    final allowedRoles = ['player', 'owner'];
    if (!allowedRoles.contains(role)) {
      return {'success': false, 'message': 'رتبة غير صالحة.'};
    }

    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'role': role,
          'name': userData['name']?.toString().trim() ?? '',
          'position': userData['position'] ?? 'GK',
          'phone': phone,
          'governorate': userData['governorate'],
        },
      );
      
      final user = response.user;
      if (user == null) {
        return {'success': false, 'message': 'فشل إنشاء الحساب.'};
      }

      return {'success': true, 'user': user};
    } on AuthException catch (e) {
      VSPLogger.e("Supabase Sign Up AuthException: ${e.message}", e);
      return {'success': false, 'message': e.message};
    } catch (e) {
      VSPLogger.e("Supabase Sign Up Exception", e);
      _logSecurityEvent('AUTH_UNKNOWN_ERROR', e);
      return {'success': false, 'message': 'خطأ غير معروف في المصادقة.'};
    }
  }

  // Sign In
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (kDebugMode && AppConfig.useMockOtp) {
      final role = cleanEmail.contains('owner') ? 'owner' : 'player';
      final mockUserId = role == 'player' ? '8d3d7d65-a167-4138-b36c-85bbdead1b7a' : 'f64e7da9-6af7-47f2-9916-87cc7e6a1739';
      
      final mockUser = User(
        id: mockUserId,
        email: cleanEmail,
        createdAt: DateTime.now().toIso8601String(),
        aud: 'authenticated',
        role: 'authenticated',
        appMetadata: {},
        userMetadata: {},
      );
      _mockUser = mockUser;
      return {'success': true, 'user': mockUser};
    }
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      return {
        'success': true, 
        'user': response.user
      };
    } on AuthException catch (e) {
      _logSecurityEvent('LOGIN_ATTEMPT_FAILED', e.message);
      return {
        'success': false, 
        'message': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'
      };
    } catch (e) {
      _logSecurityEvent('SIGN_IN_CRITICAL_FAILURE', e);
      return {'success': false, 'message': 'فشل تسجيل الدخول.'};
    }
  }

  // Sign Out
  Future<void> signOut() async {
    VSPLogger.i('🚪 Sign-Out Initiated');
    _mockUser = null;
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      _logSecurityEvent('SUPABASE_SIGN_OUT_ERROR', e);
      VSPLogger.e('❌ Supabase signOut error', e);
    }
    VSPLogger.i('👋 Sign-Out Complete');
  }

  // Send Password Reset Email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'io.supabase.fluttervsp://reset-callback/',
      );
      return true;
    } catch (e) {
      _logSecurityEvent('PASSWORD_RESET_FAILED', e);
      return false;
    }
  }

  // Send Verification Resend
  Future<bool> sendEmailVerification() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) return false;
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user.email!,
      );
      return true;
    } catch (e) {
      _logSecurityEvent('EMAIL_VERIFICATION_SENT_FAILED', e);
      return false;
    }
  }

  // Check Email Verified
  Future<bool> checkEmailVerified() async {
    try {
      final response = await _supabase.auth.getUser();
      return response.user?.emailConfirmedAt != null;
    } catch (e) {
      return false;
    }
  }

  // Sign In with Google
  Future<Map<String, dynamic>> signInWithGoogle({String? role}) async {
    try {
      final success = await _supabase.auth.signInWithOAuthSecure(
        OAuthProvider.google,
        options: SignInWithOAuthOptions(
          redirectTo: kIsWeb 
              ? '${Uri.base.origin}/' 
              : 'io.supabase.fluttervsp://login-callback/',
          queryParams: const {'prompt': 'select_account'},
          data: {'role': role ?? 'player'},
        ),
      );
      if (success) {
        return {'success': true, 'user': _supabase.auth.currentUser};
      }
      return {'success': false, 'message': 'فشل الدخول عبر جوجل.'};
    } catch (e) {
      _logSecurityEvent('GOOGLE_AUTH_ERROR', e);
      return {'success': false, 'message': 'حدث خطأ في خدمة جوجل.'};
    }
  }

  // Sign In with Apple
  Future<Map<String, dynamic>> signInWithApple({String? role}) async {
    try {
      final success = await _supabase.auth.signInWithOAuthSecure(
        OAuthProvider.apple,
        options: SignInWithOAuthOptions(
          redirectTo: kIsWeb 
              ? '${Uri.base.origin}/' 
              : 'io.supabase.fluttervsp://login-callback/',
          data: {'role': role ?? 'player'},
        ),
      );
      if (success) {
        return {'success': true, 'user': _supabase.auth.currentUser};
      }
      return {'success': false, 'message': 'فشل تسجيل الدخول عبر آبل.'};
    } catch (e) {
      _logSecurityEvent('APPLE_AUTH_ERROR', e);
      return {'success': false, 'message': 'حدث خطأ في خدمة آبل.'};
    }
  }

  // Update Password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      _logSecurityEvent('PASSWORD_UPDATE_FAILED', e);
      return false;
    }
  }

  // Delete Account
  Future<Map<String, dynamic>> deleteAccount(String uid) async {
    try {
      // In Supabase, cascading triggers in PostgreSQL handles deleting related entries.
      // We delete the user profile row, and then sign out.
      await _supabase.from('users').delete().eq('id', uid);
      await signOut();
      return {'success': true};
    } catch (e) {
      _logSecurityEvent('ACCOUNT_DELETION_FAILED', e);
      return {'success': false, 'message': 'فشل في حذف الحساب.'};
    }
  }

  // Duplicate phone check
  Future<bool> isPhoneRegistered(String phone, {String? excludeUserId}) async {
    if (phone.isEmpty) return false;
    try {
      final cleanPhone = PhoneUtils.normalize(phone);
      var query = _supabase
          .from('users')
          .select('id')
          .eq('phone', cleanPhone);
      // 🛡️ BUG FIX: Exclude the current user's own record to prevent false
      // "phone already registered" errors during social onboarding.
      if (excludeUserId != null && excludeUserId.isNotEmpty) {
        query = query.neq('id', excludeUserId);
      }
      final response = await query;
      return (response as List).isNotEmpty;
    } catch (e) {
      _logSecurityEvent('PHONE_CHECK_FAILED', e);
      return false;
    }
  }

  // Developer bypass manual verification
  Future<bool> verifyEmailManual(String uid) async {
    try {
      await _supabase.from('users').update({
        'isEmailVerified': true,
      }).eq('id', uid);
      return true;
    } catch (e) {
      _logSecurityEvent('MANUAL_VERIFICATION_BYPASS_FAILED', e);
      return false;
    }
  }

  // Verify OTP via Supabase Auth
  Future<bool> verifyOtp({required String email, required String token}) async {
    if (kDebugMode && AppConfig.useMockOtp) {
      if (token == AppConfig.mockOtpCode) {
        if (_mockUser != null) {
          try {
            await verifyEmailManual(_mockUser!.id);
          } catch (_) {}
        }
        return true;
      }
    }
    try {
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: token,
      );
      return response.session != null;
    } catch (e) {
      _logSecurityEvent('OTP_VERIFICATION_FAILED', e);
      return false;
    }
  }
}

class SignInWithOAuthOptions {
  final String? redirectTo;
  final Map<String, String>? queryParams;
  final Map<String, dynamic>? data;

  const SignInWithOAuthOptions({
    this.redirectTo,
    this.queryParams,
    this.data,
  });
}

extension GoTrueClientOAuthSecure on GoTrueClient {
  Future<bool> signInWithOAuthSecure(
    OAuthProvider provider, {
    required SignInWithOAuthOptions options,
  }) async {
    final Map<String, String> query = {};
    if (options.queryParams != null) {
      query.addAll(options.queryParams!);
    }
    if (options.data != null) {
      query['data'] = jsonEncode(options.data);
      options.data!.forEach((key, value) {
        query[key] = value.toString();
      });
    }
    return signInWithOAuth(
      provider,
      redirectTo: options.redirectTo,
      queryParams: query,
    );
  }
}
