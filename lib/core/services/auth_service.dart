import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Active Instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Internal logger for security auditing (Can be connected to Sentry/Firebase Crashlytics)
  void _logSecurityEvent(String event, dynamic error) {
    // For now, it logs to console, but in production, this should go to a secure log service
    debugPrint('[SECURITY_LOG] $event: $error');
  }

  // Sign Up - Secured with Role Protection
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> userData,
  }) async {
    // 1. Basic Sanitization
    final cleanEmail = email.trim().toLowerCase();
    
    // 2. Role Validation (Security Constraint)
    final allowedRoles = ['player', 'owner'];
    if (!allowedRoles.contains(role)) {
      return {'success': false, 'message': 'رتبة غير صالحة.'};
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      
      // Create User Document
      try {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': cleanEmail,
          'role': role,
          'name': userData['name']?.toString().trim() ?? '',
          'position': userData['position'] ?? 'GK',
          'phone': userData['phone']?.toString().trim() ?? '',
          'isEmailVerified': false,
          'hasStadium': false,
          'isIdentityVerified': false,
          'isRegistrationComplete': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (firestoreError) {
        _logSecurityEvent('FIRESTORE_PROFILE_SAVE_FAILED', firestoreError);
        await credential.user?.delete();
        return {'success': false, 'message': 'فشل في حفظ بيانات الملف الشخصي.'};
      }

      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'هذا البريد مسجَّل بالفعل.';
          break;
        case 'invalid-email':
          message = 'صيغة البريد الإلكتروني غير صحيحة.';
          break;
        case 'weak-password':
          message = 'كلمة المرور ضعيفة جداً.';
          break;
        default:
          message = 'عذراً، حدث خطأ في النظام. يرجى المحاولة لاحقاً.';
          break;
      }
      return {'success': false, 'message': message};
    } catch (e) {
      _logSecurityEvent('AUTH_UNKNOWN_ERROR', e);
      return {'success': false, 'message': 'خطأ غير معروف في المصادقة.'};
    }
  }

  // Sign In - Hardened messages
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      return {
        'success': true, 
        'user': credential.user
      };
    } on FirebaseAuthException catch (e) {
      _logSecurityEvent('LOGIN_ATTEMPT_FAILED', e.code);
      // Generic message to prevent User Enumeration attacks
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
    try {
      await _auth.signOut();
    } catch (e) {
      _logSecurityEvent('SIGN_OUT_ERROR', e);
    }
  }

  // Send Password Reset Email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      _logSecurityEvent('PASSWORD_RESET_FAILED', e);
      return false;
    }
  }

  // Send Verification Email
  Future<bool> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[AUTH] Cannot send verification: No current user logged in.');
        return false;
      }
      await user.sendEmailVerification();
      debugPrint('[AUTH] Verification email sent to: ${user.email}');
      return true;
    } catch (e) {
      _logSecurityEvent('EMAIL_VERIFICATION_SENT_FAILED', e);
      return false;
    }
  }

  // Check Email Verified
  Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      return false;
    }
  }

  // Sign In with Google - Hardened
  Future<Map<String, dynamic>> signInWithGoogle({String? role}) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return {
        'success': false,
        'message': 'Google Sign-In is only supported on Android/iOS.',
      };
    }

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return {'success': false, 'message': 'تم إلغاء العملية.'};

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          // Verify role before injecting
          final validatedRole = (role == 'owner' || role == 'player') ? role : 'player';
          
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? '',
            'phone': user.phoneNumber ?? '',
            'role': validatedRole,
            'photoUrl': user.photoURL,
            'isEmailVerified': true, // Google accounts are verified
            'hasStadium': false,
            'isIdentityVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
            'isRegistrationComplete': false,
          });
        }
        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': 'فشل الدخول عبر جوجل.'};
    } catch (e) {
      _logSecurityEvent('GOOGLE_AUTH_ERROR', e);
      return {'success': false, 'message': 'حدث خطأ في خدمة جوجل.'};
    }
  }

  // Get User Data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      _logSecurityEvent('FETCH_USER_DATA_FAILED', e);
      return null;
    }
  }

  // Update User Profile - REMOVED SENSITIVE FIELD UPDATES
  Future<bool> updateUserProfile(String uid, Map<String, dynamic> data) async {
    // SECURITY: Prevent users from updating sensitive fields like 'role' or 'uid' via client-side map
    final securedData = Map<String, dynamic>.from(data);
    securedData.remove('role');
    securedData.remove('uid');
    securedData.remove('email');
    securedData.remove('createdAt');
    
    securedData['updatedAt'] = FieldValue.serverTimestamp();

    try {
      await _firestore.collection('users').doc(uid).update(securedData);
      return true;
    } catch (e) {
      _logSecurityEvent('UPDATE_PROFILE_FAILED', e);
      return false;
    }
  }
  // Update Password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return true;
    } catch (e) {
      _logSecurityEvent('PASSWORD_UPDATE_FAILED', e);
      return false;
    }
  }
}
