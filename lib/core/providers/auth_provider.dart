import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final NotificationService _notificationService = NotificationService();
  
  // Firebase user
  User? _firebaseUser;
  UserModel? _userModel;
  
  // Registration flow state
  String? _userType; // 'player' or 'owner'
  String? _email;
  String? _verificationCode;
  String? _password;
  String? _name;
  String? _phone;
  String? _position = 'GK';
  String _governorate = 'Cairo';
  
  // Loading and error states
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  String? get userType => _userType;
  String get email => _email ?? '';
  String? get name => _name ?? _userModel?.name;
  String? get phone => _phone;
  String get position => _userModel?.position ?? _position ?? 'GK';
  String get governorate => _userModel?.governorate ?? _governorate;
  String? get profileImageUrl => _userModel?.profileImageUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isPlayer => _userModel?.role == 'player' || _userType == 'player';
  bool get isOwner => _userModel?.role == 'owner' || _userType == 'owner';
  User? get currentUser => _firebaseUser; // Alias for convenience

  AuthProvider() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) async {
      _firebaseUser = user;
      
      if (user != null) {
        // Fetch User Data from Firestore
        final userData = await _authService.getUserData(user.uid);
        if (userData != null) {
          _userModel = UserModel.fromFirestore(userData);
          _updateFcmToken(user.uid); // Silent update
        } else {
          // 🚨 SAFETY VALVE: User exists in Auth but NO data in Firestore
          // Force logout to prevent stuck Splash Screen
          await _authService.signOut();
          _firebaseUser = null;
          _userModel = null;
        }
      } else {
        _userModel = null;
        _userType = null; // Clear cached userType if NOT logged in
      }
      
      _isLoading = false; // Ensure loading stops
      notifyListeners();
    });
  }

  /// Silently update FCM token in Firestore
  Future<void> _updateFcmToken(String uid) async {
    try {
      final token = await _notificationService.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
          'lastSeen': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM Token updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating FCM Token: $e');
    }
  }

  // ==================== Registration Flow Methods ====================
  
  /// Set user type (player/owner) - Step 1
  void setUserType(String type) {
    _userType = type;
    notifyListeners();
  }

  /// Set email - Step 2
  void setEmail(String email) {
    _email = email;
    notifyListeners();
  }

  /// Set name
  void setName(String name) {
    _name = name;
    notifyListeners();
  }

  /// Set phone
  void setPhone(String phone) {
    _phone = phone;
    notifyListeners();
  }

  /// Set position
  void setPosition(String position) {
    _position = position;
    notifyListeners();
  }

  void setGovernorate(String gov) {
    _governorate = gov;
    notifyListeners();
  }

  /// Set verification code (for mock verification)
  void setVerificationCode(String code) {
    _verificationCode = code;
  }

  /// Set password
  void setPassword(String password) {
    _password = password;
  }

  /// Finalize account creation / Update password and flags
  Future<bool> createAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // If we have a stored password (from signup or set password screen), update it
      if (_password != null && _password!.isNotEmpty) {
        final success = await _authService.updatePassword(_password!);
        if (!success) {
          _errorMessage = 'Failed to update password. Please try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Update Firestore flag
      final updateSuccess = await updateProfile({
        'isRegistrationComplete': true,
      });

      if (updateSuccess) {
        // Locally update model to prevent loop
        if (_userModel != null) {
          _userModel = _userModel!.copyWith(isRegistrationComplete: true);
        }
      }

      _isLoading = false;
      notifyListeners();
      return updateSuccess;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign In with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle(role: _userType);

      if (result['success']) {
        _firebaseUser = result['user'];
        final userData = await _authService.getUserData(_firebaseUser!.uid);
        if (userData != null) {
          _userModel = UserModel.fromFirestore(userData);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset registration flow
  void reset() {
    _userType = null;
    _email = null;
    _password = null;
    _name = null;
    _phone = null;
    _errorMessage = null;
    _position = 'GK';
    notifyListeners();
  }

  // ==================== Authentication Methods ====================

  /// Sign up with email and password (direct method)
  Future<bool> signUp({
    required String email,
    required String password,
    required String role,
    Map<String, dynamic>? userData,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signUpWithEmail(
        email: email,
        password: password,
        role: role,
        userData: {
          ...userData ?? {},
          'governorate': _governorate,
        },
      );

      if (result['success']) {
        _firebaseUser = result['user'];
        _userModel = UserModel(
          uid: _firebaseUser!.uid,
          email: email,
          role: role,
          name: userData?['name'],
          phone: userData?['phone'],
          position: userData?['position'] ?? 'GK',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (result['success']) {
        _firebaseUser = result['user'];
        
        // Fetch User Data from Firestore
        final userData = await _authService.getUserData(_firebaseUser!.uid);
        
        if (userData != null) {
            _userModel = UserModel.fromFirestore(userData);
        } else {
             // Fallback if user document missing (shouldn't happen ideally)
            _userModel = UserModel(
                uid: _firebaseUser!.uid,
                email: email,
                role: 'player', // Default
            );
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _firebaseUser = null;
    _userModel = null;
    reset(); // Clear registration flow data too
    notifyListeners();
  }

  /// Update user profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_firebaseUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      bool success = await _authService.updateUserProfile(_firebaseUser!.uid, data);
      if (success && _userModel != null) {
        _userModel = _userModel!.copyWith(
          name: data['name'] ?? _userModel!.name,
          phone: data['phone'] ?? _userModel!.phone,
          profileImageUrl: data['profileImageUrl'] ?? _userModel!.profileImageUrl,
          position: data['position'] ?? _userModel!.position,
          isEmailVerified: data['isEmailVerified'] ?? _userModel!.isEmailVerified,
          hasStadium: data['hasStadium'] ?? _userModel!.hasStadium,
          isIdentityVerified: data['isIdentityVerified'] ?? _userModel!.isIdentityVerified,
          isRegistrationComplete: data['isRegistrationComplete'] ?? _userModel!.isRegistrationComplete,
        );
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update Profile Photo (now uses Cloudinary instead of Firebase Storage)
  Future<void> updateProfilePhoto(XFile file) async {
     if (_firebaseUser == null) return;
     
     _isLoading = true;
     _errorMessage = null; // ✅ Reset error message
     notifyListeners();

     try {
       final uid = _firebaseUser!.uid;

       // 1) Upload image to Cloudinary in a specific user folder
       final url = await _cloudinaryService.uploadImage(
         file,
         folder: 'users/$uid/profile',
       );

       if (url != null) {
         // 2) IMMEDIATELY update local model (Optimistic Update)
         if (_userModel != null) {
           _userModel = _userModel!.copyWith(profileImageUrl: url);
           notifyListeners();
         }

         // 3) Update profile data in Firestore in background
         updateProfile({'profileImageUrl': url}).then((success) {
           if (!success) {
               _errorMessage = 'Failed to update profile image record.';
               notifyListeners();
           }
         });
       } else {
         _errorMessage = 'Failed to upload profile image to cloud.';
       }
     } catch (e) {
       _errorMessage = 'Failed to upload profile image: $e';
     } finally {
       _isLoading = false;
       notifyListeners();
     }
  }

  Future<bool> completeSocialRegistration({
    required String phone,
    required String password,
    String? position,
    String? governorate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Update Password in Firebase Auth
      final passSuccess = await _authService.updatePassword(password);
      if (!passSuccess) {
        _errorMessage = 'Failed to set password. Your session might have expired. Please log in again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Prepare update data
      final Map<String, dynamic> updateData = {
        'phone': phone,
        'governorate': governorate ?? _governorate,
        'isRegistrationComplete': true,
      };
      if (position != null) {
        updateData['position'] = position;
      }

      // 3. Locally update _userModel IMMEDIATELY to prevent RootScreen loop
      if (_userModel != null) {
        _userModel = _userModel!.copyWith(
          phone: phone,
          governorate: governorate ?? _governorate,
          position: position ?? _userModel!.position,
          isRegistrationComplete: true,
        );
      }

      // 4. Sync to Firestore in the background
      await updateProfile(updateData);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }



  /// Simulate sending verification code
  Future<bool> sendVerificationCode() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Logic for sending code (could be cloud function or backend)
      // For now, in Demo Mode we just simulate success
      await Future.delayed(const Duration(seconds: 1));
      
      _verificationCode = '123456'; // Mock code
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify code
  Future<bool> verifyCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));
      
      if (code == _verificationCode || code == '123456') { // Allow 123456 as master bypass
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid verification code';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bool success = await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      
      if (!success) {
        _errorMessage = 'Failed to send password reset email';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
