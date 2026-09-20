import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth/social_auth_service.dart';
import 'logger_service.dart';
import 'secure_storage_service.dart';

export 'auth/social_auth_service.dart';

class AuthService {
  final SupabaseClient? _client;
  final SocialAuthService? _socialAuthService;

  AuthService({
    SupabaseClient? client,
    SocialAuthService? socialAuthService,
  })  : _client = client,
        _socialAuthService = socialAuthService;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  SocialAuthService get _socialAuth =>
      _socialAuthService ?? SocialAuthService(client: _client);

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// دالة آمنة تضمن عدم الانهيار وتطالب بجلسة صالحة
  Future<User> requireCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
      );
    }
    return user;
  }

  // Stream of auth state changes mapped to User?
  Stream<User?> get authStateChanges => _supabase.auth.onAuthStateChange.map((
    data,
  ) {
    debugPrint(
      '🔥 AUTH STATE CHANGED: event=${data.event}, user=${data.session?.user.email}',
    );
    if (data.session != null) {
      SecureStorageService.saveAuthToken(data.session!.accessToken);
    }
    return data.session?.user;
  });

  // Internal logger for security auditing
  void _logSecurityEvent(String event, dynamic error) {
    debugPrint('[SECURITY_LOG] $event: $error');
  }

  /// دالة منفصلة للتحقق والدخول التلقائي في حالة وجود حساب سابق لنفس البريد والدور
  Future<Map<String, dynamic>?> signInIfExistingSameRoleAccount({
    required String email,
    required String password,
    required String role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final emailCheck = await _supabase
          .from('users')
          .select('id, role')
          .eq('email', cleanEmail)
          .maybeSingle();

      if (emailCheck != null) {
        final existingRole = emailCheck['role']?.toString();

        if (existingRole != null && existingRole != role) {
          final arabicExistingRole = existingRole == 'player'
              ? 'لاعب'
              : 'مالك ملعب';
          return {
            'success': false,
            'message':
                'هذا البريد مسجل مسبقاً كـ $arabicExistingRole. '
                'يرجى تسجيل الدخول بحسابك أو استخدام بريد آخر.',
          };
        }

        try {
          final signInResponse = await _supabase.auth.signInWithPassword(
            email: cleanEmail,
            password: password,
          );
          if (signInResponse.user != null) {
            VSPLogger.i(
              'Existing $role re-signed in automatically: $cleanEmail',
            );
            return {'success': true, 'user': signInResponse.user};
          }
        } catch (_) {
          return {
            'success': false,
            'message':
                'البريد الإلكتروني مسجل بالفعل. تأكد من كلمة المرور الصحيحة أو سجّل دخولك.',
          };
        }
        return {'success': false, 'message': 'البريد الإلكتروني مسجل بالفعل.'};
      }
    } catch (e) {
      _logSecurityEvent('EMAIL_CHECK_FAILED', e);
    }
    return null; // Account does not exist, proceed with sign up
  }

  // Sign Up - Pure new user creation
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> userData,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check for existing account first via helper
    final existingCheck = await signInIfExistingSameRoleAccount(
      email: cleanEmail,
      password: password,
      role: role,
    );
    if (existingCheck != null) {
      return existingCheck;
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
          'phone': userData['phone']?.toString().trim() ?? '',
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
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      return {'success': true, 'user': response.user};
    } on AuthException catch (e) {
      _logSecurityEvent('LOGIN_ATTEMPT_FAILED', e.message);
      return {
        'success': false,
        'message': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      };
    } catch (e) {
      _logSecurityEvent('SIGN_IN_CRITICAL_FAILURE', e);
      return {'success': false, 'message': 'فشل تسجيل الدخول.'};
    }
  }

  // Sign Out
  Future<void> signOut() async {
    VSPLogger.i(' Sign-Out Initiated');
    try {
      if (!kIsWeb) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          await googleSignIn.signOut();
        } catch (_) {}
      }
      await _supabase.auth.signOut();
      await SecureStorageService.clearAll();
    } catch (e) {
      await SecureStorageService.clearAll();
      _logSecurityEvent('SUPABASE_SIGN_OUT_ERROR', e);
      VSPLogger.e(' Supabase signOut error', e);
    }
    VSPLogger.i(' Sign-Out Complete');
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
      await _supabase.auth.resend(type: OtpType.signup, email: user.email!);
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

  // Sign In with Google (delegated to SocialAuthService)
  Future<Map<String, dynamic>> signInWithGoogle({String? role}) =>
      _socialAuth.signInWithGoogle(role: role);

  // Sign In with Apple (delegated to SocialAuthService)
  Future<Map<String, dynamic>> signInWithApple({String? role}) =>
      _socialAuth.signInWithApple(role: role);

  // Update Password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      _logSecurityEvent('PASSWORD_UPDATE_FAILED', e);
      return false;
    }
  }

  // Delete Account — server-side atomic flow only.
  Future<Map<String, dynamic>> deleteAccount(String uid) async {
    try {
      final response = await _supabase.rpc(
        'delete_user_permanently',
        params: {'p_user_id': uid},
      );
      final data = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      if (data['success'] != true) {
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'فشل في حذف الحساب.',
        };
      }
      await signOut();
      return {'success': true};
    } catch (e) {
      _logSecurityEvent('ACCOUNT_DELETION_FAILED', e);
      return {'success': false, 'message': 'فشل في حذف الحساب.'};
    }
  }

  // Verify OTP via Supabase Auth
  Future<bool> verifyOtp({required String email, required String token}) async {
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

