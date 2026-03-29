import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
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
  final StorageService _storageService = StorageService();
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
  bool _isInitializing = true; // 🔥 Added for session stability
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

  bool get isInitializing => _isInitializing; // 🔥 Exposed for RootScreen gating

  bool _initialStateCaptured = false; // 🔥 To ensure we capture the FIRST auth state

  AuthProvider() {
    _loadOnboardingStatus();
    
    // ⚡ INITIALIZATION FIX: Start with isInitializing = true
    _firebaseUser = _authService.currentUser;
    if (_firebaseUser != null) {
      _fetchUserData(_firebaseUser!);
    }

    // Listen to subsequent auth state changes
    _authService.authStateChanges.listen((User? user) async {
      final isFirstTime = !_initialStateCaptured;
      _initialStateCaptured = true;
      
      // Avoid redundant triggers if user is the same
      if (user?.uid == _firebaseUser?.uid && _userModel != null) {
         _isInitializing = false;
         notifyListeners();
         return;
      }
      
      _firebaseUser = user;
      _errorMessage = null; 
      
      if (user != null) {
        await _fetchUserData(user);
      } else {
        // GRACE PERIOD: On startup, give Firebase a moment to restore persistence
        if (isFirstTime) {
          await Future.delayed(const Duration(milliseconds: 1500));
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            _firebaseUser = currentUser;
            await _fetchUserData(currentUser);
            return;
          }
        }
        
        _userModel = null;
        _isGhostUser = false;
        _userType = null; 
        _isLoading = false;
        _isInitializing = false;
        notifyListeners();
      }
    });
  }

  /// Internal helper to fetch data without redundant notifyListeners
  Future<void> _fetchUserData(User user) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        _userModel = UserModel.fromFirestore(userData);
        _isGhostUser = false;
        _updateFcmToken(user.uid);
        _dataFetchError = false;
        NotificationHandler.checkAndSendDebtAlerts(user.uid);
      } else {
        VSPLogger.w("⚠️ Ghost user detected (UID: ${user.uid})");
        _isGhostUser = true;
        _userModel = null;
      }
    } catch (e) {
      VSPLogger.e("❌ AuthProvider: Firestore fetch exception", e);
      _dataFetchError = true;
    } finally {
      _isLoading = false;
      _isInitializing = false; // ✅ Initial load finished
      notifyListeners();
    }
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
    // SECURITY PATCH: Clear FCM token from Firestore before logout
    if (_firebaseUser != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_firebaseUser!.uid).update({
          'fcmToken': FieldValue.delete(),
        });
        VSPLogger.i('FCM Token cleared for logout');
      } catch (e) {
        VSPLogger.w('Silent failure clearing FCM token during logout');
      }
    }

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

  /// Update Profile Photo
  Future<void> updateProfilePhoto(XFile file) async {
     if (_firebaseUser == null) return;
     
     _isLoading = true;
     _errorMessage = null; // ✅ Reset error message
     notifyListeners();

     try {
       final uid = _firebaseUser!.uid;
       final oldUrl = _userModel?.profileImageUrl;

       // 1) Upload image to Firebase Storage (and delete old one)
       final url = await _storageService.uploadProfilePicture(
         file: File(file.path),
         userId: uid,
         oldImageUrl: oldUrl,
       );
       if (url == null) throw 'Upload returned null';

        // 2) IMMEDIATELY update local model (Optimistic Update)
        if (_userModel != null) {
          _userModel = _userModel!.copyWith(profileImageUrl: url);
          notifyListeners();
        }

        // 3) Update profile data in Firestore
        await updateProfile({'profileImageUrl': url});
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

  /// 📍 Auto-update user location based on GPS with Throttling
  Future<void> updateUserLocation() async {
    if (_userModel == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString('last_location_update');
      final lastLat = prefs.getDouble('last_lat') ?? 0.0;
      final lastLng = prefs.getDouble('last_lng') ?? 0.0;

      final now = DateTime.now();
      
      // 1. Check Time Threshold (Once every 24 hours)
      bool timeThresholdMet = lastUpdateStr == null || 
          now.difference(DateTime.parse(lastUpdateStr)).inHours >= 24;

      // 2. Check Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // 3. Get Current Position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );

      // 4. Check Distance Threshold (More than 5km)
      double distanceInMeters = Geolocator.distanceBetween(
        lastLat, lastLng, position.latitude, position.longitude
      );

      if (timeThresholdMet || distanceInMeters > 5000) {
        VSPLogger.i("🌍 GPS Optimized: Threshold met. Updating location...");
        
        _currentPosition = position;
        notifyListeners();

        final placemarks = await placemarkFromCoordinates(
          position.latitude, 
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final rawName = placemarks.first.administrativeArea ?? placemarks.first.subAdministrativeArea ?? placemarks.first.locality;
          final newGov = EgyptGovernorates.resolveGoogleName(rawName);

          if (_userModel!.governorate != newGov) {
            await updateProfile({'governorate': newGov});
          }
          
          // Persist update state to throttle subsequent calls
          await prefs.setString('last_location_update', now.toIso8601String());
          await prefs.setDouble('last_lat', position.latitude);
          await prefs.setDouble('last_lng', position.longitude);
        }
      } else {
        VSPLogger.i("🌍 GPS Optimized: Using cached location (Throttled)");
      }
    } catch (e) {
      VSPLogger.w('Error auto-updating location (Silenced): $e');
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

  /// [DEVELOPER BYPASS] Manually verify email status in Firestore
  Future<bool> verifyEmailManual(String uid) async {
    _isLoading = true;
    notifyListeners();
    
    final success = await _authService.verifyEmailManual(uid);
    
    if (success && _userModel != null) {
      _userModel = _userModel!.copyWith(isEmailVerified: true);
    }
    
    _isLoading = false;
    notifyListeners();
    return success;
  }
}
