import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Active Instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign Up
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> userData,
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create User Document
      try {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'role': role,
          'name': userData['name'] ?? '',
          'position': userData['position'] ?? 'GK',
          'phone': userData['phone'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (firestoreError) {
        // CLEANUP: If Firestore fails, we MUST delete the newly created auth user
        // so they can try again with the same email.
        await credential.user?.delete();
        return {'success': false, 'message': 'Failed to save profile: $firestoreError'};
      }

      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'هذا البريد مسجَّل بالفعل. إذا كان هذا حسابك، يرجى تسجيل الدخول أو استخدام بريد آخر.';
          break;
        case 'invalid-email':
          message = 'صيغة البريد الإلكتروني غير صحيحة.';
          break;
        case 'weak-password':
          message = 'كلمة المرور ضعيفة، يرجى اختيار كلمة أقوى.';
          break;
        default:
          message = 'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى.';
          break;
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign In
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Fetch user role from Firestore if needed, or rely on UI to fetch profile later
      // For login, just returning success and user is enough
      
      return {
        'success': true, 
        'user': credential.user
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send Password Reset Email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get User Data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Update User Profile
  Future<bool> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }
}
