import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
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
  
  // Loading and error states
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  String? get userType => _userType;
  String get email => _email ?? '';
  String? get name => _name;
  String? get phone => _phone;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isPlayer => _userModel?.role == 'player';
  bool get isOwner => _userModel?.role == 'owner';
  User? get currentUser => _firebaseUser; // Alias for convenience

  AuthProvider() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) {
      _firebaseUser = user;
      if (user == null) {
        _userModel = null;
      }
      notifyListeners();
    });
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

  /// Set verification code (for mock verification)
  void setVerificationCode(String code) {
    _verificationCode = code;
  }

  /// Set password
  void setPassword(String password) {
    _password = password;
  }

  /// Send verification code (mock implementation)
  Future<bool> sendVerificationCode() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Mock: Generate a 6-digit code
      _verificationCode = '123456'; // In production, send via email/SMS
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
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
      await Future.delayed(const Duration(milliseconds: 500));
      
      bool isValid = code == _verificationCode;
      
      if (!isValid) {
        _errorMessage = 'Invalid verification code';
      }
      
      _isLoading = false;
      notifyListeners();
      return isValid;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Create account - Final step
  Future<bool> createAccount() async {
    if (_email == null || _password == null || _userType == null) {
      _errorMessage = 'Missing required information';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signUpWithEmail(
        email: _email!,
        password: _password!,
        role: _userType!,
        userData: {
          'name': _name ?? '',
          'phone': _phone ?? '',
        },
      );

      if (result['success']) {
        _firebaseUser = result['user'];
        _userModel = UserModel(
          uid: _firebaseUser!.uid,
          email: _email!,
          role: _userType!,
          name: _name,
          phone: _phone,
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

  /// Reset registration flow
  void reset() {
    _userType = null;
    _email = null;
    _verificationCode = null;
    _password = null;
    _name = null;
    _phone = null;
    _errorMessage = null;
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
        userData: userData ?? {},
      );

      if (result['success']) {
        _firebaseUser = result['user'];
        _userModel = UserModel(
          uid: _firebaseUser!.uid,
          email: email,
          role: role,
          name: userData?['name'],
          phone: userData?['phone'],
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
