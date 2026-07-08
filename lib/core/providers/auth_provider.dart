import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/logger_service.dart';
import '../utils/phone_utils.dart';
import '../repositories/user_repository.dart';
import '../config/app_config.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final LocationService _locationService = LocationService();
  final UserRepository _userRepository = UserRepository();
  
  // Supabase user
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
  bool _isFetchingUser = false; // Concurrency guard for profile fetch

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
  bool _preserveError = false; // 🔥 Preserve error message across silent sign-outs

  AuthProvider() {
    _loadOnboardingStatus();
    
    // ⚡ INITIALIZATION FIX: Start with isInitializing = true
    _firebaseUser = _authService.currentUser;
    if (_firebaseUser != null) {
      _fetchUserData(_firebaseUser!);
    }

    // 🛡️ WEB SAFE-TIMEOUT: Prevents infinite Splash deadlock
    Future.delayed(const Duration(seconds: 5), () {
      if (_isInitializing) {
        _isInitializing = false;
        notifyListeners();
        VSPLogger.w("⚠️ Auth Safe-Timeout triggered: Supabase auth stream did not emit. Bypassing splash deadlock.");
      }
    });

    // Listen to subsequent auth state changes
    _authService.authStateChanges.listen((User? user) async {
      _initialStateCaptured = true;
      
      // Avoid redundant triggers if user is the same
      if (user?.id == _firebaseUser?.id && _userModel != null) {
         _isInitializing = false;
         notifyListeners();
         return;
      }
      
      _firebaseUser = user;
      if (!_preserveError) {
        _errorMessage = null;
      } else {
        _preserveError = false;
      }
      
      if (user != null) {
        await _fetchUserData(user);
      } else {
        _stopRealtimeUserListener();
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
    if (_isFetchingUser) return;
    _isFetchingUser = true;
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingRole = prefs.getString('pending_oauth_role');
      if (pendingRole != null) {
        _userType = pendingRole; // استعادة الخيار المفقود
        await prefs.remove('pending_oauth_role'); // حذفه فوراً
      }

      Map<String, dynamic>? userData;
      int retries = 3;
      while (retries > 0) {
        userData = await _userRepository.getUserData(user.id);
        if (userData != null) break;
        retries--;
        if (retries > 0) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (userData != null) {
        final dbRole = userData['role']?.toString();

        // ===== ROLE CONFLICT GUARD =====
        // If the user chose a specific role on the sign-up screen (_userType is
        // set) and their DB record has a DIFFERENT role:
        if (_userType != null && dbRole != null && dbRole != _userType) {
          final bool isRegComplete = userData['is_registration_complete'] == true ||
              userData['isRegistrationComplete'] == true;

          if (!isRegComplete) {
            // 💡 NEW SIGN-UP: Registration is NOT complete.
            // Do NOT block. Instead, update the role in the database to match _userType,
            // update local role data, and let them proceed.
            VSPLogger.i('🔄 Role mismatch during incomplete signup: Updating DB role from $dbRole to $_userType');
            try {
              // Direct query to public.users to update the role since the profile is incomplete
              await Supabase.instance.client
                  .from('users')
                  .update({'role': _userType})
                  .eq('id', user.id);
              // Update the in-memory userData map to reflect the new role
              userData['role'] = _userType;
            } catch (e) {
              VSPLogger.e('Failed to correct role in DB for incomplete signup', e);
            }
          } else {
            // 💡 EXISTING USER WITH ROLE MISMATCH: Respect database role silently.
            VSPLogger.w('⚠️ User clicked $_userType but is already registered as $dbRole. Respecting database role.');
            _userType = null; // Let the system use the actual database role
          }
        }
        // ===== END ROLE CONFLICT GUARD =====

        _userModel = UserModel.fromFirestore(userData);
        
        // ⚡ SYNC EMAIL VERIFIED FROM AUTH SOURCE OF TRUTH
        // The DB column (is_email_verified) can be stale for users registered
        // before the trigger fix. Always trust the Supabase Auth object instead:
        // - Google/Apple users: emailConfirmedAt is set automatically by the provider
        // - Email/password users: emailConfirmedAt is set after OTP confirmation
        final bool isActuallyEmailVerified = user.emailConfirmedAt != null;
        if (_userModel != null && isActuallyEmailVerified && !_userModel!.isEmailVerified) {
          _userModel = _userModel!.copyWith(isEmailVerified: true);
          // Silently patch the DB column so it's consistent going forward
          _userRepository.updateUserProfile(
            user.id,
            {'is_email_verified': true},
            authUser: user,
            role: userData['role']?.toString(),
          );
        }

        // ⚡ FIX: Only auto-complete registration if the user ACTUALLY has a phone number.
        // This ensures new social sign-ups are forced to the onboarding screen.
        final bool hasValidPhone = _userModel != null && 
                                   _userModel!.phone != null && 
                                   _userModel!.phone!.trim().isNotEmpty;
                                   
        if (_userModel != null && !_userModel!.isRegistrationComplete && hasValidPhone) {
          _userModel = _userModel!.copyWith(isRegistrationComplete: true);
          _userRepository.updateUserProfile(
            user.id,
            {'isRegistrationComplete': true},
            authUser: user,
            role: userData['role']?.toString(),
          );
        }

        // ===== AUTO-LOGIN REDIRECT =====
        // For an existing complete user (phone set + isRegistrationComplete),
        // clear _userType so GoRouter routes by their DB role, not the
        // sign-up screen they came from. This prevents ghost-user onboarding.
        final hasPhone = (_userModel != null && _userModel!.phone?.isNotEmpty == true);
        if (_userModel != null && _userModel!.isRegistrationComplete && hasPhone) {
          _userType = null; // let GoRouter use userModel.role
        }
        // ===== END AUTO-LOGIN REDIRECT =====

        _isGhostUser = false;
        _updateFcmToken(user.id);
        _dataFetchError = false;
        _startRealtimeUserListener(user.id);
      } else {
        VSPLogger.w("⚠️ Ghost user detected (UID: ${user.id})");
        _isGhostUser = true;
        _userModel = null;
      }
    } catch (e, stack) {
      VSPLogger.e("❌ AuthProvider: Supabase fetch exception", e, stack);
      _dataFetchError = true;
    } finally {
      _isFetchingUser = false;
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
      final userData = await _userRepository.getUserData(_firebaseUser!.id);
      if (userData != null) {
        _userModel = UserModel.fromFirestore(userData);
        _updateFcmToken(_firebaseUser!.id);
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

  /// Silently update FCM token in Supabase
  Future<void> _updateFcmToken(String uid) async {
    try {
      final token = await _notificationService.getToken();
      if (token != null) {
        await Supabase.instance.client.from('users').update({
          'fcmToken': token,
          'lastSeen': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', uid);
        VSPLogger.i('FCM Token sync status: SUCCESS');
      }
    } catch (e) {
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
      if (_password != null && _password!.isNotEmpty) {
        final success = await _authService.updatePassword(_password!);
        if (!success) {
          _errorMessage = 'Failed to update password. Please try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      final success = await _userRepository.updateUserProfile(
        currentUser!.id, 
        {
          'name': _name,
          'phone': PhoneUtils.normalize(_phone ?? ''),
          'position': _position,
          'isRegistrationComplete': true,
        },
        authUser: currentUser,
        role: _userType ?? _userModel?.role,
      );
      
      if (success) {
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
  ///
  /// On WEB: signInWithOAuth opens a browser redirect/popup.
  /// The actual user session arrives via the authStateChanges stream AFTER the
  /// OAuth flow completes — NOT synchronously here. We must NOT try to read
  /// currentUser immediately; that would always be null and crash.
  ///
  /// On MOBILE: signInWithOAuth may also be async depending on the platform.
  /// The authStateChanges listener in AuthProvider() already handles session
  /// pickup for both platforms, so this method only needs to trigger the flow.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_oauth_role', _userType ?? 'player');

      final result = await _authService.signInWithGoogle(role: _userType);

      if (result['success']) {
        // ✅ On web: result['user'] is null here because the browser has just
        // been redirected to Google. The authStateChanges listener will fire
        // once the user returns and the session is established.
        // We only update _firebaseUser if the service returned a real user
        // (mobile deep-link callback scenario).
        final returnedUser = result['user'] as User?;
        if (returnedUser != null) {
          // Mobile: session is immediately available
          _firebaseUser = returnedUser;
          await _fetchUserData(returnedUser);
        } else {
          // Web: session comes via authStateChanges — nothing to do here.
          // The loading spinner will be dismissed when the stream fires.
          _isLoading = false;
          notifyListeners();
        }
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
  /// Same async pattern as signInWithGoogle — session arrives via authStateChanges.
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_oauth_role', _userType ?? 'player');

      final result = await _authService.signInWithApple(role: _userType);

      if (result['success']) {
        final returnedUser = result['user'] as User?;
        if (returnedUser != null) {
          _firebaseUser = returnedUser;
          await _fetchUserData(returnedUser);
        } else {
          _isLoading = false;
          notifyListeners();
        }
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

  /// Sign up with email and password
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
        final existingData = await _userRepository.getUserData(_firebaseUser!.id);
        if (existingData != null) {
          _userModel = UserModel.fromFirestore(existingData);
          // ⚡ TIMING FIX: If this is an already-registered user signing in via
          // the signup flow (duplicate email), their DB row might have
          // isRegistrationComplete=false. Force it to true locally BEFORE
          // notifyListeners fires so GoRouter doesn't redirect to /onboarding.
          if (!_userModel!.isRegistrationComplete) {
            _userModel = _userModel!.copyWith(isRegistrationComplete: true);
            // Persist fix to DB silently in the background.
            _userRepository.updateUserProfile(
              _firebaseUser!.id,
              {'isRegistrationComplete': true},
              authUser: _firebaseUser,
              role: existingData['role'] ?? role,
            );
          }
        } else {
          _userModel = UserModel(
            uid: _firebaseUser!.id,
            email: email,
            role: role,
            name: userData?['name'],
            phone: userData?['phone'],
            position: userData?['position'] ?? 'GK',
            dateOfBirth: userData?['date_of_birth'] != null
                ? DateTime.tryParse(userData!['date_of_birth'])
                : null,
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
        final userData = await _userRepository.getUserData(_firebaseUser!.id);
        
        if (userData != null) {
            _userModel = UserModel.fromFirestore(userData);
            // ⚡ TIMING FIX: An existing profile means the user previously
            // completed registration. Force isRegistrationComplete=true so
            // GoRouter does NOT redirect them to /onboarding after login.
            if (!_userModel!.isRegistrationComplete) {
              _userModel = _userModel!.copyWith(isRegistrationComplete: true);
              _userRepository.updateUserProfile(
                _firebaseUser!.id,
                {'isRegistrationComplete': true},
                authUser: _firebaseUser,
                role: userData['role'] ?? _userModel?.role,
              );
            }
        } else {
            _userModel = UserModel(
                uid: _firebaseUser!.id,
                email: email,
                role: 'player',
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
    if (_firebaseUser != null) {
      try {
        await Supabase.instance.client.from('users').update({
          'fcmToken': null,
        }).eq('id', _firebaseUser!.id);
        VSPLogger.i('FCM Token cleared for logout');
      } catch (e) {
        VSPLogger.w('Silent failure clearing FCM token during logout');
      }
    }

    _stopRealtimeUserListener();
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
      bool success = await _userRepository.updateUserProfile(
        _firebaseUser!.id, 
        sanitizedData,
        authUser: _firebaseUser,
        role: _userModel?.role ?? _userType,
      );
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
          verificationStatus: sanitizedData['verificationStatus'] ?? _userModel!.verificationStatus,
          dateOfBirth: sanitizedData['date_of_birth'] != null
              ? DateTime.tryParse(sanitizedData['date_of_birth'])
              : (sanitizedData['dateOfBirth'] ?? _userModel!.dateOfBirth),
          p2pInstapay: sanitizedData['p2p_instapay'] ?? sanitizedData['p2pInstapay'] ?? _userModel!.p2pInstapay,
          p2pVodafone: sanitizedData['p2p_vodafone'] ?? sanitizedData['p2pVodafone'] ?? _userModel!.p2pVodafone,
          p2pBank: sanitizedData['p2p_bank'] ?? sanitizedData['p2pBank'] ?? _userModel!.p2pBank,
          additionalData: sanitizedData['additionalData'] ?? sanitizedData['additional_data'] ?? _userModel!.additionalData,
        );
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
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
     _errorMessage = null; 
     notifyListeners();

     try {
       final uid = _firebaseUser!.id;
       final oldUrl = _userModel?.profileImageUrl;

       String? url;
       if (kIsWeb) {
         url = "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150";
       } else {
         url = await _storageService.uploadProfilePicture(
           file: file,
           userId: uid,
           oldImageUrl: oldUrl,
         );
       }
       if (url == null) throw 'Upload returned null';

        if (_userModel != null) {
          _userModel = _userModel!.copyWith(profileImageUrl: url);
          notifyListeners();
        }

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
    DateTime? dateOfBirth,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    if (await _authService.isPhoneRegistered(phone)) {
      _errorMessage = 'هذا الرقم مسجل مسبقاً، يرجى استخدام رقم آخر.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final Map<String, dynamic> updateData = {
        'phone': PhoneUtils.normalize(phone),
        'governorate': governorate ?? _governorate,
        'isRegistrationComplete': true,
        'date_of_birth': dateOfBirth?.toUtc().toIso8601String(),
      };
      if (name != null && name.isNotEmpty) {
        updateData['name'] = name;
      }
      if (position != null) {
        updateData['position'] = position;
      }

      if (_userModel != null) {
        _userModel = _userModel!.copyWith(
          name: (name != null && name.isNotEmpty) ? name : _userModel!.name,
          phone: phone,
          governorate: governorate ?? _governorate,
          position: position ?? _userModel!.position,
          isRegistrationComplete: true,
          dateOfBirth: dateOfBirth ?? _userModel!.dateOfBirth,
        );
      }

      await updateProfile(updateData);
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
      await Future.delayed(const Duration(seconds: 1));
      _verificationCode = '123456'; 
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
      if (AppConfig.useMockOtp && (code == _verificationCode || code == AppConfig.mockOtpCode)) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid verification code or mock OTP disabled in release';
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

  /// Determine the current governorate via GPS without updating profile
  Future<String?> determineGPSGovernorate({bool force = false}) async {
    final result = await _locationService.getThrottledLocation(force: force);
    if (result.$1 != null) {
      _currentPosition = result.$1;
      notifyListeners();
    }
    if (result.$2 == "mock_location_detected") {
      _errorMessage = "تنبيه الأمان: تم اكتشاف محاولة لتزييف الموقع الجغرافي (Mock Location). يرجى إيقاف برامج تزييف الموقع للمتابعة.\n\nSecurity Alert: Mock location detected. Please disable location spoofing to continue.";
      notifyListeners();
      return null;
    }
    if (result.$2 != null) {
      _governorate = result.$2!;
      notifyListeners();
    }
    return result.$2;
  }

  /// 📍 Auto-update user location based on GPS with Throttling
  Future<bool> updateUserLocation({bool force = false}) async {
    final newGov = await determineGPSGovernorate(force: force);
    if (newGov != null) {
      if (_userModel != null && _userModel!.governorate != newGov) {
        await updateProfile({'governorate': newGov});
      }
      return true;
    }
    return false;
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

  /// [DEVELOPER BYPASS] Manually verify email status
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

  /// Verify OTP token via Supabase Auth
  Future<bool> verifyOtp({required String email, required String token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _authService.verifyOtp(email: email, token: token);
      if (success) {
        // Refresh session
        _firebaseUser = _authService.currentUser;
        if (_firebaseUser != null) {
          await _fetchUserData(_firebaseUser!);
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

  /// Resend OTP verification
  Future<bool> resendOtp() async {
    return await _authService.sendEmailVerification();
  }
  RealtimeChannel? _userChannel;
  final StreamController<void> _celebrationController = StreamController<void>.broadcast();
  Stream<void> get celebrationEvents => _celebrationController.stream;

  void _startRealtimeUserListener(String userId) {
    _stopRealtimeUserListener();

    VSPLogger.i('📡 Starting real-time subscription for user profile: $userId');
    _userChannel = Supabase.instance.client
        .channel('public:users:id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            VSPLogger.i('⚡ Real-time update received for user profile: ${payload.newRecord}');
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty && _userModel != null) {
              final newModel = UserModel.fromFirestore(newRecord);
              
              final oldStatus = _userModel!.verificationStatus;
              final newStatus = newModel.verificationStatus;
              
              _userModel = newModel;
              notifyListeners();

              // Trigger confetti celebration if verified/approved
              if ((oldStatus == 'pending' || oldStatus == null) && newStatus == 'approved') {
                VSPLogger.i('🎉 Owner approved! Triggering celebration events.');
                _celebrationController.add(null);
              }
            }
          },
        );
    _userChannel!.subscribe();
  }

  void _stopRealtimeUserListener() {
    if (_userChannel != null) {
      VSPLogger.i('📡 Stopping real-time subscription for user profile');
      Supabase.instance.client.removeChannel(_userChannel!);
      _userChannel = null;
    }
  }

  @override
  void dispose() {
    _stopRealtimeUserListener();
    _celebrationController.close();
    super.dispose();
  }
}

extension SupabaseUserExtension on User {
  String get uid => id;
}



