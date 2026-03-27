import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/phone_utils.dart';
import 'logger_service.dart';
import '../constants/egypt_governorates.dart';

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
    
    // 2. Duplicate Phone Check (Phase 3 Hardening)
    final rawPhone = userData['phone']?.toString() ?? '';
    final phone = PhoneUtils.normalize(rawPhone);
    if (await isPhoneRegistered(phone)) {
       return {'success': false, 'message': 'رقم الهاتف مسجل مسبقاً.'};
    }

    // 3. Role Validation (Security Constraint)
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
          'phone': PhoneUtils.normalize(userData['phone']?.toString() ?? ''),
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
    VSPLogger.i('🚪 Sign-Out Initiated');
    
    // 1. Firebase Sign-Out
    try {
      await _auth.signOut();
    } catch (e) {
      _logSecurityEvent('FIREBASE_SIGN_OUT_ERROR', e);
      VSPLogger.e('❌ Firebase signOut error', e);
    }

    // 2. Google Sign-Out (Try to disconnect to clear all scopes/cache)
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
        VSPLogger.i('✅ Google account disconnected');
      }
    } catch (e) {
      // Often fails if not initialized or already disconnected, but catch avoids PlatformException crash
      _logSecurityEvent('GOOGLE_SIGN_OUT_CHANNEL_ERROR', e);
      VSPLogger.w('⚠️ Google sign-out non-critical error: $e');
    }
    
    VSPLogger.i('👋 Sign-Out Complete');
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

  // SECURITY PATCH: Redacted email address in console logs to protect user privacy.
  Future<bool> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[AUTH] Cannot send verification: No current user logged in.');
        return false;
      }
      await user.sendEmailVerification();
      debugPrint('[AUTH] Verification email sent to: USER_IDENTITY_PROTECTED');
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

  // Sign In with Google - Forced Account Picker
  Future<Map<String, dynamic>> signInWithGoogle({String? role}) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return {
        'success': false,
        'message': 'Google Sign-In is only supported on Android/iOS.',
      };
    }

    try {
      final googleSignIn = GoogleSignIn();
      
      // 🔴 FIX: Force sign out first to clear previous session cache
      // This ensures the account picker dialog shows up every time.
      await googleSignIn.signOut(); 

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
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

  // Sign In with Apple (iOS only ideally, but Firebase handles web fallback)
  Future<Map<String, dynamic>> signInWithApple({String? role}) async {
    try {
      final appleProvider = AppleAuthProvider();
      // Request full name and email
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      final UserCredential userCredential = await _auth.signInWithProvider(appleProvider);
      final user = userCredential.user;

      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          final validatedRole = (role == 'owner' || role == 'player') ? role : 'player';
          
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email ?? '', // Apple might hide email
            'name': user.displayName ?? 'Apple User',
            'phone': '',
            'role': validatedRole,
            'photoUrl': user.photoURL,
            'isEmailVerified': true, // Apple accounts are verified
            'hasStadium': false,
            'isIdentityVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
            'isRegistrationComplete': false,
          });
        }
        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': 'فشل تسجيل الدخول عبر آبل.'};
    } catch (e) {
      _logSecurityEvent('APPLE_AUTH_ERROR', e);
      return {'success': false, 'message': 'حدث خطأ في خدمة آبل.'};
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

  // SECURITY PATCH: Stripped sensitive fields (role, points, walletBalance, etc.) to prevent privilege escalation or data manipulation.
  Future<bool> updateUserProfile(String uid, Map<String, dynamic> data) async {
    // TODO: SECURITY - BIG REMINDER FOR BACKEND TEAM
    // Client-side field removal is NOT enough. You MUST enforce Firestore Security Rules 
    // to strictly prevent writes to `role`, `commissionDebt`, and `walletBalance` by regular users.
    
    // SECURITY: Prevent users from elevating privileges via client-side map.
    // Fields explicitly blocked: role, uid, email, createdAt, points, walletBalance, isEmailVerified.
    // NOTE: isIdentityVerified, isRegistrationComplete, hasStadium are intentionally ALLOWED —
    // these are onboarding-state flags that must be writable by the owner flow.
    // They are not security-sensitive: admins can revoke them via Firestore directly.
    final securedData = Map<String, dynamic>.from(data);
    securedData.remove('role');
    securedData.remove('uid');
    securedData.remove('email');
    securedData.remove('createdAt');
    securedData.remove('isEmailVerified'); // Must go through Firebase Auth, not Firestore
    securedData.remove('points');
    securedData.remove('walletBalance');
    
    // 🌍 Standardize Governorate
    if (securedData.containsKey('governorate')) {
      final String? gov = securedData['governorate']?.toString();
      if (gov != null) {
        // We import it here or at top
        securedData['governorate'] = EgyptGovernorates.resolveGoogleName(gov);
      }
    }

    securedData['updatedAt'] = FieldValue.serverTimestamp();

    try {
      // 🔴 FIX: Use set(merge: true) instead of update()
      // This allows 'Ghost Users' (who have Auth but no Firestore doc) to have their
      // profile created automatically during onboarding completion.
      await _firestore.collection('users').doc(uid).set(securedData, SetOptions(merge: true));
      return true;
    } catch (e) {
      _logSecurityEvent('UPDATE_PROFILE_FAILED', e);
      VSPLogger.e('❌ Failed to update/create user profile for UID: $uid', e);
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

  // Phase 2: User Deletion Logic (Safe Delete)
  Future<Map<String, dynamic>> deleteAccount(String uid) async {
    try {
      // 1. Promote Next Captain in Teams
      final teamSnap = await _firestore.collection('teams')
          .where('memberUids', arrayContains: uid)
          .get();

      final batch = _firestore.batch();
      
      for (var doc in teamSnap.docs) {
        final data = doc.data();
        final memberUids = List<String>.from(data['memberUids'] ?? []);
        
        // If they are the captain (first in list)
        if (memberUids.isNotEmpty && memberUids[0] == uid) {
          memberUids.removeAt(0);
          if (memberUids.isNotEmpty) {
            // Promote next member
            final nextCaptainUid = memberUids[0];
            final nextCaptainDoc = await _firestore.collection('users').doc(nextCaptainUid).get();
            final nextCaptainName = nextCaptainDoc.data()?['name'] ?? 'Captain';
            
            batch.update(doc.reference, {
              'memberUids': memberUids,
              'captainName': nextCaptainName,
            });
          } else {
            // No more members, delete team
            batch.delete(doc.reference);
          }
        } else {
          // Just remove them from members
          memberUids.remove(uid);
          batch.update(doc.reference, {'memberUids': memberUids});
        }
      }

      // 2. Delete User Profile
      batch.delete(_firestore.collection('users').doc(uid));
      
      await batch.commit();

      // 3. Delete Auth User
      await _auth.currentUser?.delete();
      
      return {'success': true};
    } catch (e) {
      _logSecurityEvent('ACCOUNT_DELETION_FAILED', e);
      return {'success': false, 'message': 'فشل في حذف الحساب.'};
    }
  }

  // duplicate phone check
  Future<bool> isPhoneRegistered(String phone) async {
    if (phone.isEmpty) return false;
    final cleanPhone = PhoneUtils.normalize(phone);
    final snapshot = await _firestore.collection('users')
        .where('phone', isEqualTo: cleanPhone)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
