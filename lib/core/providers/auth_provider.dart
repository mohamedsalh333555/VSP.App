import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/logger_service.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../utils/phone_utils.dart';
import '../services/notification_handler.dart';
import '../../../../core/constants/egypt_governorates.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final NotificationService _notificationService = NotificationService();
  
  // Firebase user
  User? _firebaseUser;
  UserModel? _userModel;
  Position? _currentPosition;
  bool _hasCompletedOnboarding = false;
  
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
  Position? get currentPosition => _currentPosition;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  bool _dataFetchError = false;
  bool get hasDataFetchError => _dataFetchError;

  bool _isGhostUser = false;
  bool get isGhostUser => _isGhostUser;

  AuthProvider() {
    _loadOnboardingStatus();
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) async {
      _firebaseUser = user;
      _errorMessage = null; 
      _dataFetchError = false;
      
      if (user != null) {
        _isLoading = true;
        notifyListeners();
        
        try {
          // Fetch User Data from Firestore
          final userData = await _authService.getUserData(user.uid);
          if (userData != null) {
            _userModel = UserModel.fromFirestore(userData);
            _isGhostUser = false;
            _updateFcmToken(user.uid); // Silent update
            _dataFetchError = false;

            // ── DEBT CHECKER (Phase 4 Automation) ──
            // Audit unpaid bookings and send alerts/execute blocks
            NotificationHandler.checkAndSendDebtAlerts(user.uid);
            
            if (_userModel?.isBlocked ?? false) {
              VSPLogger.w("🚫 User ${user.uid} is BLOCKED due to debt.");
            }
          } else {
            // 🚨 GHOST SESSION DETECTION: Auth exists but Firestore doc is missing.
            VSPLogger.w("⚠️ Ghost user detected (UID: ${user.uid}). Auth exists, Firestore missing.");
            _isGhostUser = true;
            _userModel = null;
          }
        } catch (e) {
          VSPLogger.e("❌ AuthProvider: Firestore fetch exception", e);
          _dataFetchError = true;
          _isGhostUser = false;
        } finally {
          _isLoading = false;
          notifyListeners();
        }
      } else {
        _userModel = null;
        _isGhostUser = false;
        _userType = null; 
        _dataFetchError = false;
        _isLoading = false;
        notifyListeners();
      }
      
      _isLoading = false; 
      notifyListeners();
    });
  }

  /// Manual retry for when data fetching fails but auth is valid
  Future<void> retryDataFetch() async {
    if (_firebaseUser == null) return;
    
    _isLoading = true;
    _dataFetchError = false;
    notifyListeners();
    
    try {
      final userData = await _authService.getUserData(_firebaseUser!.uid);
      if (userData != null) {
        _userModel = UserModel.fromFirestore(userData);
        _updateFcmToken(_firebaseUser!.uid);
        _dataFetchError = false;
      } else {
        _dataFetchError = true;
      }
    } catch (e) {
      _dataFetchError = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
        // SECURITY PATCH: Obfuscated success message to prevent token sniffing in logs.
        VSPLogger.i('FCM Token sync status: SUCCESS');
      }
    } catch (e) {
      // SECURITY PATCH: Masked error details for notification service failure.
      VSPLogger.w('FCM Token sync status: FAILED (Silent)');
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

      // 2. Update other profile data
      final success = await _authService.updateUserProfile(currentUser!.uid, {
        'name': _name, // Assuming _name is set
        'phone': PhoneUtils.normalize(_phone ?? ''), // Assuming _phone is set
        'position': _position, // Assuming _position is set
        'isRegistrationComplete': true,
      });
      
      if (success) {
        // Locally update model to prevent loop
        if (_userModel != null) {
          _userModel = _userModel!.copyWith(isRegistrationComplete: true);
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
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
        _firebaseUser = result['user'] as User?;
        final userData = await _authService.getUserData(_firebaseUser!.uid);
        
        if (userData != null) {
          _userModel = UserModel.fromFirestore(userData);
        } else {
          // 🚨 HYDRATION FIX: Manually build the model for new Google users 
          // to prevent the "Connection Problem" flickering screen.
          _userModel = UserModel(
            uid: _firebaseUser!.uid,
            email: _firebaseUser!.email ?? '',
            name: _firebaseUser!.displayName ?? '',
            role: _userType ?? 'player',
            isRegistrationComplete: false,
            isEmailVerified: true,
            hasStadium: false,
            isIdentityVerified: false,
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

  /// Sign In with Apple
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithApple(role: _userType);

      if (result['success']) {
        _firebaseUser = result['user'] as User?;
        final userData = await _authService.getUserData(_firebaseUser!.uid);
        
        if (userData != null) {
          _userModel = UserModel.fromFirestore(userData);
        } else {
          _userModel = UserModel(
            uid: _firebaseUser!.uid,
            email: _firebaseUser!.email ?? '',
            name: _firebaseUser!.displayName ?? 'Apple User',
            role: _userType ?? 'player',
            isRegistrationComplete: false,
            isEmailVerified: true,
            hasStadium: false,
            isIdentityVerified: false,
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

  /// Sign out - HARD RESET for Beta
  Future<void> signOut() async {
    await _authService.signOut();
    _firebaseUser = null;
    _userModel = null;
    _userType = null;
    _dataFetchError = false;
    _errorMessage = null; 
    reset(); // Clear registration flow data too
    notifyListeners();
  }

  /// Update user profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_firebaseUser == null) return false;

    // SECURITY HARDENING: Prevent malicious client-side injection of privileged fields.
    // Only truly dangerous fields (role, wallet, points) are blocked.
    // Onboarding flags (hasStadium, isIdentityVerified, isRegistrationComplete) are ALLOWED
    // so the owner flow can progress naturally.
    final sanitizedData = Map<String, dynamic>.from(data);
    const restrictedFields = [
      'role', 
      'points', 
      'walletBalance', 
      'isVerified', 
      'isEmailVerified',
      'lastSeen',
      'fcmToken'
    ];
    for (var field in restrictedFields) {
      sanitizedData.remove(field);
    }
    
    if (sanitizedData.containsKey('phone')) {
      sanitizedData['phone'] = PhoneUtils.normalize(sanitizedData['phone'] ?? '');
    }
    
    if (sanitizedData.isEmpty) return true; // Nothing allowed to update

    _isLoading = true;
    notifyListeners();

    try {
      bool success = await _authService.updateUserProfile(_firebaseUser!.uid, sanitizedData);
      if (success && _userModel != null) {
        _userModel = _userModel!.copyWith(
          name: sanitizedData['name'] ?? _userModel!.name,
          phone: sanitizedData['phone'] ?? _userModel!.phone,
          profileImageUrl: sanitizedData['profileImageUrl'] ?? _userModel!.profileImageUrl,
          position: sanitizedData['position'] ?? _userModel!.position,
          hasStadium: sanitizedData['hasStadium'] ?? _userModel!.hasStadium,
          isRegistrationComplete: sanitizedData['isRegistrationComplete'] ?? _userModel!.isRegistrationComplete,
          isIdentityVerified: sanitizedData['isIdentityVerified'] ?? _userModel!.isIdentityVerified,
          governorate: sanitizedData['governorate'] ?? _userModel!.governorate,
          favoriteStadiums: sanitizedData['favoriteStadiums'] ?? _userModel!.favoriteStadiums,
        );
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      // SECURITY PATCH: Sanitize internal error messages. Avoid leaking Firestore/internal details to UI.
      debugPrint("❌ Profile update error: Masked for security.");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleFavoriteStadium(String stadiumId) async {
    if (_userModel == null) return;

    final updatedList = List<String>.from(_userModel!.favoriteStadiums);
    if (updatedList.contains(stadiumId)) {
      updatedList.remove(stadiumId);
    } else {
      updatedList.add(stadiumId);
    }

    await updateProfile({'favoriteStadiums': updatedList});
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
     } catch (e) {
       _errorMessage = 'Failed to upload profile image: $e';
     } finally {
       _isLoading = false;
       notifyListeners();
     }
  }

  Future<bool> completeSocialRegistration({
    required String phone,
    String? name,
    String? position,
    String? governorate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    // 0. Duplicate Phone Check (Phase 3 Hardening)
    if (await _authService.isPhoneRegistered(phone)) {
      _errorMessage = 'هذا الرقم مسجل مسبقاً، يرجى استخدام رقم آخر.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      // 1. Prepare update data
      final Map<String, dynamic> updateData = {
        'phone': PhoneUtils.normalize(phone),
        'governorate': governorate ?? _governorate,
        // REMOVED: 'isRegistrationComplete': true, -> Let user pass OTP first
      };
      if (name != null && name.isNotEmpty) {
        updateData['name'] = name;
      }
      if (position != null) {
        updateData['position'] = position;
      }

      // 3. Locally update _userModel IMMEDIATELY
      if (_userModel != null) {
        _userModel = _userModel!.copyWith(
          name: (name != null && name.isNotEmpty) ? name : _userModel!.name,
          phone: phone,
          governorate: governorate ?? _governorate,
          position: position ?? _userModel!.position,
          // REMOVED: isRegistrationComplete: true,
        );
      }

      // 4. Sync to Firestore
      await updateProfile(updateData);
      
      // 5. Critical: Clear ghost status now that Firestore doc exists
      _isGhostUser = false;

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

  /// 📍 Auto-update user location based on GPS
  Future<void> updateUserLocation() async {
    // Only update if user is logged in
    if (_userModel == null) return;

    try {
      // 1. Check & Request Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // 2. Get Current Position
      // City-level accuracy is enough
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      _currentPosition = position;
      notifyListeners();

      // 3. Reverse Geocode (Get Governorate Name)
      final placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final rawName = placemarks.first.administrativeArea ?? placemarks.first.subAdministrativeArea ?? placemarks.first.locality;
        final newGov = EgyptGovernorates.resolveGoogleName(rawName);

        // 4. Update Profile ONLY if changed
        if (_userModel!.governorate != newGov) {
          debugPrint('📍 Auto-updating location: ${_userModel!.governorate} -> $newGov');
          await updateProfile({'governorate': newGov});
        }
      }
    } catch (e) {
      VSPLogger.e('Error auto-updating location', e);
      // Fail silently, don't disturb user
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load onboarding status from SharedPreferences
  Future<void> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
    notifyListeners();
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  // Phase 2: User Deletion Logic (Safe Delete)
  Future<bool> deleteAccount() async {
    if (_userModel == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.deleteAccount(_userModel!.uid);
      if (result['success']) {
        await signOut();
        _isLoading = false;
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred while deleting your account.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
