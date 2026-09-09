import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_env.dart';

/// Handles third-party social authentication flows (Google and Apple sign-in).
class SocialAuthService {
  final SupabaseClient? _client;

  SocialAuthService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  void _logSecurityEvent(String event, dynamic error) {
    debugPrint('[SECURITY_LOG] $event: $error');
  }

  /// Sign In with Google (Native Google Play Sheet on Mobile + Web OAuth Fallback)
  Future<Map<String, dynamic>> signInWithGoogle({String? role}) async {
    try {
      // 1. Mobile (Android / iOS): Native Google Play Services Sheet (Fast & No Browser)
      if (!kIsWeb) {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: AppEnv.googleWebClientId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? AppEnv.googleIosClientId
              : null,
          scopes: ['email', 'profile'],
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User closed the Google bottom sheet
          return {'success': false, 'message': 'تم إلغاء تسجيل الدخول'};
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? idToken = googleAuth.idToken;
        final String? accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw Exception('لم يتم استلام idToken من حساب جوجل');
        }

        final AuthResponse response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        if (response.user != null) {
          return {'success': true, 'user': response.user};
        }
      }

      // 2. Fallback for Web or devices without Google Play Services
      final String redirectUrl = kIsWeb
          ? '${Uri.base.origin}/'
          : (role != null
                ? 'io.supabase.fluttervsp://login-callback/?role=$role'
                : 'io.supabase.fluttervsp://login-callback/');

      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );

      if (success) {
        return {'success': true, 'user': _supabase.auth.currentUser};
      }
      return {'success': false, 'message': 'فشل تسجيل الدخول عبر جوجل.'};
    } catch (e) {
      _logSecurityEvent('GOOGLE_AUTH_ERROR', e);

      // Fallback: If Native Google sheet fails unexpectedly on mobile, attempt Web OAuth as safe fallback
      if (!kIsWeb) {
        try {
          final String redirectUrl = role != null
              ? 'io.supabase.fluttervsp://login-callback/?role=$role'
              : 'io.supabase.fluttervsp://login-callback/';
          final success = await _supabase.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: redirectUrl,
            authScreenLaunchMode: LaunchMode.externalApplication,
            queryParams: const {'prompt': 'select_account'},
          );
          if (success) {
            return {'success': true, 'user': _supabase.auth.currentUser};
          }
        } catch (_) {}
      }

      return {'success': false, 'message': 'حدث خطأ في خدمة جوجل: $e'};
    }
  }

  /// Sign In with Apple (Native iOS with Face ID / Touch ID + Web fallback)
  Future<Map<String, dynamic>> signInWithApple({String? role}) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // 1. Generate Nonce for Supabase cryptographic verification
        final rawNonce = _supabase.auth.generateRawNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

        // 2. Request native Apple ID Credential
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );

        final idToken = credential.identityToken;
        if (idToken == null) {
          return {
            'success': false,
            'message': 'فشل الحصول على رمز الهوية من Apple.',
          };
        }

        // 3. Sign in to Supabase using ID Token directly
        final authResponse = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        );

        final user = authResponse.user;
        if (user != null) {
          return {'success': true, 'user': user};
        }
        return {'success': false, 'message': 'فشل تسجيل الدخول عبر Apple.'};
      } else {
        // Fallback for Web/other platforms: Web-based OAuth redirect
        final String redirectUrl = kIsWeb
            ? '${Uri.base.origin}/'
            : (role != null
                  ? 'io.supabase.fluttervsp://login-callback/?role=$role'
                  : 'io.supabase.fluttervsp://login-callback/');

        final success = await _supabase.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: redirectUrl,
          authScreenLaunchMode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        );
        if (success) {
          return {'success': true, 'user': _supabase.auth.currentUser};
        }
        return {'success': false, 'message': 'فشل تسجيل الدخول عبر Apple.'};
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return {'success': false, 'message': 'تم إلغاء تسجيل الدخول.'};
      }
      _logSecurityEvent('APPLE_AUTH_ERROR', e);
      return {
        'success': false,
        'message': 'حدث خطأ أثناء تسجيل الدخول عبر Apple: ${e.message}',
      };
    } catch (e) {
      _logSecurityEvent('APPLE_AUTH_ERROR', e);
      return {'success': false, 'message': 'حدث خطأ في خدمة Apple: $e'};
    }
  }
}

class SignInWithOAuthOptions {
  final String? redirectTo;
  final Map<String, String>? queryParams;
  final Map<String, dynamic>? data;

  const SignInWithOAuthOptions({this.redirectTo, this.queryParams, this.data});
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
