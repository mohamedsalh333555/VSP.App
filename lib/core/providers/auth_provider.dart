import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import 'auth/auth_location_coordinator.dart';
import 'auth/auth_oauth_coordinator.dart';
import 'auth/auth_onboarding_coordinator.dart';
import 'auth/auth_otp_service.dart';
import 'auth/auth_profile_service.dart';
import 'auth/auth_realtime_coordinator.dart';
import 'auth/auth_registration_form_state.dart';
import 'auth/auth_registration_service.dart';
import 'auth/auth_session_listener.dart';
import 'auth/auth_sign_out_handler.dart';
import 'auth/auth_user_data_fetcher.dart';

export '../extensions/supabase_user_extension.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final LocationService _locationService = LocationService();
  final UserRepository _userRepository = UserRepository();

  late final AuthOAuthCoordinator _oauthCoordinator;
  late final AuthProfileService _profileService;
  late final AuthRegistrationService _registrationService;
  late final AuthRealtimeCoordinator _realtimeCoordinator;
  late final AuthUserDataFetcher _userDataFetcher;
  late final AuthOtpService _otpService;
  late final AuthLocationCoordinator _locationCoordinator;
  StreamSubscription<User?>? _authSubscription;

  // Supabase user state
  User? _firebaseUser;
  UserModel? _userModel;
  bool _hasCompletedOnboarding = false;

  // Form inputs state
  final _form = AuthRegistrationFormState();

  // Loading and error states
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;
  bool _isFetchingUser = false;
  bool _dataFetchError = false;
  bool _isGhostUser = false;
  bool _preserveError = false;

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  String? get userType => _form.userType;
  String get email => _form.email ?? _firebaseUser?.email ?? _userModel?.email ?? '';
  String? get name => _form.name ?? _userModel?.name;
  String? get phone => _form.phone;
  String get position => _userModel?.position ?? _form.position;
  String get governorate => _userModel?.governorate ?? _form.governorate;
  String? get profileImageUrl => _userModel?.profileImageUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isPlayer => _userModel != null ? !_userModel!.isOwnerRole : _form.userType == 'player';
  bool get isOwner => _userModel != null ? _userModel!.isOwnerRole : _form.userType == 'owner';
  User? get currentUser => _firebaseUser;
  Position? get currentPosition => _locationCoordinator.currentPosition;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get hasDataFetchError => _dataFetchError;
  bool get isGhostUser => _isGhostUser;
  bool get isInitializing => _isInitializing;
  Stream<void> get celebrationEvents => _realtimeCoordinator.celebrationEvents;

  AuthProvider({
    AuthService? authService,
    UserRepository? userRepository,
    StorageService? storageService,
    LocationService? locationService,
    AuthOAuthCoordinator? oauthCoordinator,
    AuthProfileService? profileService,
    AuthRegistrationService? registrationService,
    AuthRealtimeCoordinator? realtimeCoordinator,
    AuthUserDataFetcher? userDataFetcher,
    AuthOtpService? otpService,
    AuthLocationCoordinator? locationCoordinator,
  }) {
    _oauthCoordinator = oauthCoordinator ?? AuthOAuthCoordinator(authService: _authService, userRepository: _userRepository);
    _profileService = profileService ?? AuthProfileService(authService: _authService, storageService: _storageService, locationService: _locationService, userRepository: _userRepository);
    _registrationService = registrationService ?? AuthRegistrationService(authService: _authService, userRepository: _userRepository);
    _realtimeCoordinator = realtimeCoordinator ?? AuthRealtimeCoordinator();
    _userDataFetcher = userDataFetcher ?? AuthUserDataFetcher(userRepository: _userRepository);
    _otpService = otpService ?? AuthOtpService(registrationService: _registrationService);
    _locationCoordinator = locationCoordinator ?? AuthLocationCoordinator(profileService: _profileService);

    _initOnboarding();

    _firebaseUser = _authService.currentUser;
    if (_firebaseUser != null) _fetchUserData(_firebaseUser!);

    _authSubscription = AuthSessionListener.start(
      authService: _authService,
      isInitializing: () => _isInitializing,
      onTimeout: () {
        _isInitializing = false;
        notifyListeners();
      },
      onAuthStateChange: _handleAuthStateChange,
    );
  }

  Future<void> _handleAuthStateChange(User? user) async {
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
      _form.userType = null;
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _initOnboarding() async {
    _hasCompletedOnboarding = await AuthOnboardingCoordinator.loadStatus();
    notifyListeners();
  }

  Future<bool> _runAuthAction(Future<({bool success, String? error})> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final res = await action();
    _isLoading = false;
    _errorMessage = res.error;
    notifyListeners();
    return res.success;
  }

  Future<void> refreshProfile() async {
    if (_firebaseUser != null) await _fetchUserData(_firebaseUser!);
  }

  Future<void> _fetchUserData(User user) async {
    if (_isFetchingUser) return;
    _isFetchingUser = true;
    _isLoading = true;
    notifyListeners();

    final result = await _userDataFetcher.fetch(user: user, currentUserType: _form.userType);
    _isFetchingUser = false;
    _isLoading = false;
    _isInitializing = false;

    if (result.shouldSignOut) {
      await signOut();
      _errorMessage = result.errorMessage;
      notifyListeners();
      return;
    }

    _userModel = result.userModel;
    _form.userType = result.userType;
    _isGhostUser = result.isGhostUser;
    _errorMessage = result.errorMessage;
    _dataFetchError = result.dataFetchError;

    if (_userModel != null) {
      _updateFcmToken(user.id);
      _startRealtimeUserListener(user.id);
      _notificationService.listenToRealtimeNotifications(user.id);
    }
    notifyListeners();
  }

  Future<void> retryDataFetch() async {
    if (_firebaseUser == null) return;
    _isLoading = true;
    _dataFetchError = false;
    notifyListeners();

    final res = await _userDataFetcher.retryDataFetch(_firebaseUser!.id);
    _isLoading = false;
    if (res.userModel != null) {
      _userModel = res.userModel;
      _updateFcmToken(_firebaseUser!.id);
      _dataFetchError = false;
    } else {
      _dataFetchError = true;
    }
    notifyListeners();
  }

  Future<void> _updateFcmToken(String uid) async {
    final token = await _notificationService.getToken();
    await _userDataFetcher.updateFcmToken(uid, token);
  }

  void setUserType(String type) { _form.userType = type; notifyListeners(); }
  void setEmail(String email) { _form.email = email; notifyListeners(); }
  void setName(String name) { _form.name = name; notifyListeners(); }
  void setPhone(String phone) { _form.phone = phone; notifyListeners(); }
  void setPosition(String position) { _form.position = position; notifyListeners(); }
  void setGovernorate(String gov) { _form.governorate = gov; notifyListeners(); }
  void setVerificationCode(String code) { _form.verificationCode = code; notifyListeners(); }
  void setPassword(String password) => _form.password = password;

  Future<bool> createAccount() => _runAuthAction(() async {
    final res = await _registrationService.createAccount(
      currentUser: _firebaseUser,
      currentUserModel: _userModel,
      password: _form.password,
      name: _form.name,
      phone: _form.phone,
      position: _form.position,
      userType: _form.userType,
    );
    if (res.success && res.userModel != null) _userModel = res.userModel;
    return (success: res.success, error: res.error);
  });

  Future<bool> signInWithGoogle({bool isLoginOnly = false}) => _runAuthAction(() async {
    final res = await _oauthCoordinator.signInWithGoogle(isLoginOnly: isLoginOnly, userType: _form.userType);
    if (res.success && res.user != null) {
      _firebaseUser = res.user;
      await _fetchUserData(res.user!);
    }
    return (success: res.success, error: res.error);
  });

  Future<bool> signInWithApple({bool isLoginOnly = false}) => _runAuthAction(() async {
    final res = await _oauthCoordinator.signInWithApple(isLoginOnly: isLoginOnly, userType: _form.userType);
    if (res.success && res.user != null) {
      _firebaseUser = res.user;
      await _fetchUserData(res.user!);
    }
    return (success: res.success, error: res.error);
  });

  void reset() {
    _form.reset();
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String role,
    Map<String, dynamic>? userData,
  }) => _runAuthAction(() async {
    final res = await _registrationService.signUp(
      email: email, password: password, role: role, governorate: _form.governorate, userData: userData,
    );
    if (res.success) {
      _firebaseUser = res.user;
      _userModel = res.userModel;
    }
    return (success: res.success, error: res.error);
  });

  Future<bool> signIn({required String email, required String password}) => _runAuthAction(() async {
    final res = await _registrationService.signIn(email: email, password: password);
    if (res.success) {
      _firebaseUser = res.user;
      _userModel = res.userModel;
    }
    return (success: res.success, error: res.error);
  });

  Future<void> abortRegistration() async {
    await _registrationService.abortRegistration(_firebaseUser, _userModel);
    await signOut();
  }

  Future<void> signOut() async {
    await AuthSignOutHandler.performSignOut(
      user: _firebaseUser,
      userModelUid: _userModel?.uid,
      authService: _authService,
      notificationService: _notificationService,
      onClearRealtime: _stopRealtimeUserListener,
    );
    _firebaseUser = null;
    _userModel = null;
    _form.userType = null;
    _dataFetchError = false;
    _errorMessage = null;
    reset();
    notifyListeners();
  }

  Future<bool> updatePassword(String newPassword) => _profileService.updatePassword(newPassword);

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_firebaseUser == null) return false;
    _isLoading = true;
    notifyListeners();
    final res = await _profileService.updateProfile(
      authUser: _firebaseUser,
      currentUserModel: _userModel,
      userType: _form.userType,
      data: data,
    );
    if (res.success) _userModel = res.updatedModel;
    _isLoading = false;
    notifyListeners();
    return res.success;
  }

  Future<bool> completeOwnerRegistration({required String verificationStatus}) async {
    final res = await _registrationService.completeOwnerRegistration(
      authUser: _firebaseUser,
      currentUserModel: _userModel,
      verificationStatus: verificationStatus,
    );
    if (res.success && res.userModel != null) {
      _userModel = res.userModel;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> toggleFavoriteStadium(String stadiumId) async {
    if (_userModel == null) return;
    final list = _profileService.toggleFavoriteStadiumList(currentFavorites: _userModel!.favoriteStadiums, stadiumId: stadiumId);
    await updateProfile({'favoriteStadiums': list});
  }

  Future<void> updateProfilePhoto(XFile file) async {
    if (_firebaseUser == null) return;
    await _runAuthAction(() async {
      final res = await _profileService.uploadProfilePhoto(
        authUser: _firebaseUser,
        currentUserModel: _userModel,
        file: file,
      );
      if (res.success && res.imageUrl != null) {
        if (_userModel != null) _userModel = _userModel!.copyWith(profileImageUrl: res.imageUrl);
        await updateProfile({'profileImageUrl': res.imageUrl});
      }
      return (success: res.success, error: res.error);
    });
  }

  Future<bool> completeSocialRegistration({
    required String phone,
    String? name,
    String? position,
    String? governorate,
    DateTime? dateOfBirth,
    String? p2pInstapay,
    String? p2pVodafone,
    String? p2pBank,
  }) => _runAuthAction(() async {
    final res = await _oauthCoordinator.completeSocialRegistration(
      firebaseUser: _firebaseUser,
      currentUserModel: _userModel,
      userType: _form.userType,
      fallbackGovernorate: _form.governorate,
      phone: phone,
      name: name,
      position: position,
      governorate: governorate,
      dateOfBirth: dateOfBirth,
      p2pInstapay: p2pInstapay,
      p2pVodafone: p2pVodafone,
      p2pBank: p2pBank,
    );
    if (res.success) {
      _userModel = res.userModel;
      _form.userType = null;
      _isGhostUser = false;
      _dataFetchError = false;
    }
    return (success: res.success, error: res.error);
  });

  Future<bool> sendVerificationCode() => _runAuthAction(() async {
    final ok = await _otpService.sendVerificationCode(_form);
    return (success: ok, error: null);
  });

  Future<bool> verifyCode(String code) => _runAuthAction(() async {
    final match = _otpService.verifyCode(_form, code);
    return (success: match, error: match ? null : 'رمز التحقق غير صحيح');
  });

  Future<bool> resetPassword(String email) => _runAuthAction(() async {
    final ok = await _otpService.resetPassword(email);
    return (success: ok, error: ok ? null : 'Failed to send password reset email');
  });

  Future<String?> determineGPSGovernorate({bool force = false}) async {
    final res = await _locationCoordinator.determineGPSGovernorate(force: force);
    if (res.error != null) _errorMessage = res.error;
    if (res.governorate != null) _form.governorate = res.governorate!;
    notifyListeners();
    return res.governorate;
  }

  Future<bool> updateUserLocation({bool force = false}) async {
    final newGov = await determineGPSGovernorate(force: force);
    if (newGov != null && _userModel != null && _userModel!.governorate != newGov) {
      await updateProfile({'governorate': newGov});
      return true;
    }
    return newGov != null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await AuthOnboardingCoordinator.complete();
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    if (_userModel == null) return false;
    return _runAuthAction(() async {
      final res = await _profileService.deleteAccount(_userModel!);
      if (res.success) await signOut();
      return (success: res.success, error: res.error);
    });
  }

  Future<bool> verifyOtp({required String email, required String token}) => _runAuthAction(() async {
    final ok = await _otpService.verifyOtp(email: email, token: token);
    if (ok) {
      _firebaseUser = _authService.currentUser;
      if (_firebaseUser != null) await _fetchUserData(_firebaseUser!);
    }
    return (success: ok, error: ok ? null : 'Failed to verify OTP');
  });

  Future<bool> resendOtp() => _otpService.resendOtp();

  void _startRealtimeUserListener(String userId) {
    _realtimeCoordinator.startRealtimeUserListener(
      userId: userId,
      getUserModel: () => _userModel,
      getFirebaseUser: () => _firebaseUser,
      onUserUpdated: (newModel) {
        _userModel = newModel;
        notifyListeners();
      },
    );
  }

  void _stopRealtimeUserListener() {
    _realtimeCoordinator.stopRealtimeUserListener();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _realtimeCoordinator.dispose();
    super.dispose();
  }

  Future<bool> payRehabilitationFine() => _runAuthAction(() async {
    if (_firebaseUser == null) return (success: false, error: null);
    final ok = await _profileService.payRehabilitationFine(_firebaseUser!.id);
    if (ok && _userModel != null) _userModel = _userModel!.copyWith(noShowCount: 0, isBlocked: false);
    return (success: ok, error: ok ? null : 'فشل سداد الغرامة');
  });
}
