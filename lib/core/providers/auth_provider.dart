import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'auth/auth_account_coordinator.dart';
import 'auth/auth_coordinators.dart';
import 'auth/auth_location_coordinator.dart';
import 'auth/auth_onboarding_coordinator.dart';
import 'auth/auth_otp_service.dart';
import 'auth/auth_profile_coordinator.dart';
import 'auth/auth_profile_service.dart';
import 'auth/auth_realtime_coordinator.dart';
import 'auth/auth_registration_form_state.dart';
import 'auth/auth_session_listener.dart';
import 'auth/auth_session_sync_coordinator.dart';
import 'auth/auth_sign_out_handler.dart';

export '../extensions/supabase_user_extension.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final AuthCoordinators _c;
  StreamSubscription<User?>? _authSubscription;

  // Supabase user state
  User? _supabaseUser;
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
  bool _locationUpdateInProgress = false;

  // Getters
  @Deprecated('Use currentUser instead')
  User? get firebaseUser => _supabaseUser;
  UserModel? get userModel => _userModel;
  String? get userType => _form.userType;
  String get email =>
      _form.email ?? _supabaseUser?.email ?? _userModel?.email ?? '';
  String? get name => _form.name ?? _userModel?.name;
  String? get phone => _form.phone;
  String get position => _userModel?.position ?? _form.position;
  String get governorate => _userModel?.governorate ?? _form.governorate;
  String? get profileImageUrl => _userModel?.profileImageUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _supabaseUser != null;
  bool get isPlayer =>
      _userModel != null ? _userModel!.isPlayer : _form.userType == 'player';
  bool get isOwner =>
      _userModel != null ? _userModel!.isOwner : _form.userType == 'owner';
  bool get isAdmin => _userModel?.isAdmin ?? false;
  User? get currentUser => _supabaseUser;
  Position? get currentPosition => _c.location.currentPosition;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get hasDataFetchError => _dataFetchError;
  bool get isGhostUser => _isGhostUser;
  bool get isInitializing => _isInitializing;
  Stream<void> get celebrationEvents => _c.realtime.celebrationEvents;

  AuthProvider({
    AuthService? authService,
    AuthCoordinators? coordinators,
    AuthAccountCoordinator? accountCoordinator,
    AuthProfileService? profileService,
    AuthRealtimeCoordinator? realtimeCoordinator,
    AuthSessionSyncCoordinator? sessionSyncCoordinator,
    AuthOtpService? otpService,
    AuthLocationCoordinator? locationCoordinator,
    AuthProfileCoordinator? profileCoordinator,
  }) : _authService = authService ?? AuthService(),
       _c =
           coordinators ??
           AuthCoordinators(
             account: accountCoordinator,
             profileService: profileService,
             realtime: realtimeCoordinator,
             sessionSync: sessionSyncCoordinator,
             otp: otpService,
             location: locationCoordinator,
             profile: profileCoordinator,
             authService: authService,
           ) {
    _initOnboarding();
    _supabaseUser = _authService.currentUser;
    if (_supabaseUser != null) _fetchUserData(_supabaseUser!);

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
    if (user?.id == _supabaseUser?.id && _userModel != null) {
      _isInitializing = false;
      notifyListeners();
      return;
    }
    _supabaseUser = user;
    if (!_preserveError) {
      _errorMessage = null;
    } else {
      _preserveError = false;
    }

    if (user != null) {
      await _fetchUserData(user);
    } else {
      _c.realtime.stopRealtimeUserListener();
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

  Future<bool> _runAuthAction(
    Future<({bool success, String? error})> Function() action,
  ) async {
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
    if (_supabaseUser != null) await _fetchUserData(_supabaseUser!);
  }

  Future<void> _fetchUserData(User user) async {
    if (_isFetchingUser) return;
    _isFetchingUser = true;
    _isLoading = true;
    notifyListeners();

    final result = await _c.sessionSync.fetchUserData(
      user: user,
      currentUserType: _form.userType,
    );
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
      _c.sessionSync.updateFcmToken(user.id);
      _c.realtime.startRealtimeUserListener(
        userId: user.id,
        getUserModel: () => _userModel,
        getFirebaseUser: () => _supabaseUser,
        onUserUpdated: (newModel) {
          _userModel = newModel;
          notifyListeners();
        },
      );
      _c.sessionSync.listenToRealtimeNotifications(user.id);
    }
    notifyListeners();
  }

  Future<void> retryDataFetch() async {
    if (_supabaseUser == null) return;
    _isLoading = true;
    _dataFetchError = false;
    notifyListeners();

    final model = await _c.sessionSync.retryDataFetch(_supabaseUser!.id);
    _isLoading = false;
    if (model != null) {
      _userModel = model;
      _dataFetchError = false;
    } else {
      _dataFetchError = true;
    }
    notifyListeners();
  }

  void setUserType(String type) {
    _form.userType = type;
    notifyListeners();
  }

  void setEmail(String email) {
    _form.email = email;
    notifyListeners();
  }

  void setName(String name) {
    _form.name = name;
    notifyListeners();
  }

  void setPhone(String phone) {
    _form.phone = phone;
    notifyListeners();
  }

  void setPosition(String position) {
    _form.position = position;
    notifyListeners();
  }

  void setGovernorate(String gov) {
    _form.governorate = gov;
    notifyListeners();
  }

  void setVerificationCode(String code) {
    _form.verificationCode = code;
    notifyListeners();
  }

  void setPassword(String password) => _form.password = password;

  Future<bool> createAccount() => _runAuthAction(() async {
    final res = await _c.account.createAccount(
      currentUser: _supabaseUser,
      currentUserModel: _userModel,
      form: _form,
    );
    if (res.success && res.userModel != null) _userModel = res.userModel;
    return (success: res.success, error: res.error);
  });

  Future<bool> signInWithGoogle({bool isLoginOnly = false}) =>
      _runAuthAction(() async {
        final res = await _c.account.signInWithGoogle(
          isLoginOnly: isLoginOnly,
          userType: _form.userType,
        );
        if (res.success && res.user != null) {
          _supabaseUser = res.user;
          await _fetchUserData(res.user!);
        }
        return (success: res.success, error: res.error);
      });

  Future<bool> signInWithApple({bool isLoginOnly = false}) =>
      _runAuthAction(() async {
        final res = await _c.account.signInWithApple(
          isLoginOnly: isLoginOnly,
          userType: _form.userType,
        );
        if (res.success && res.user != null) {
          _supabaseUser = res.user;
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
    final res = await _c.account.signUp(
      email: email,
      password: password,
      role: role,
      governorate: _form.governorate,
      userData: userData,
    );
    if (res.success) {
      _supabaseUser = res.user;
      _userModel = res.userModel;
    }
    return (success: res.success, error: res.error);
  });

  Future<bool> signIn({required String email, required String password}) =>
      _runAuthAction(() async {
        final res = await _c.account.signIn(email: email, password: password);
        if (res.success) {
          _supabaseUser = res.user;
          _userModel = res.userModel;
        }
        return (success: res.success, error: res.error);
      });

  Future<void> abortRegistration() async {
    await _c.account.abortRegistration(
      user: _supabaseUser,
      userModel: _userModel,
    );
    await signOut();
  }

  Future<void> signOut() async {
    await AuthSignOutHandler.performSignOut(
      user: _supabaseUser,
      userModelUid: _userModel?.uid,
      authService: _authService,
      notificationService: _c.sessionSync.notificationService,
      onClearRealtime: _c.realtime.stopRealtimeUserListener,
    );
    _supabaseUser = null;
    _userModel = null;
    _form.userType = null;
    _dataFetchError = false;
    _errorMessage = null;
    reset();
    notifyListeners();
  }

  Future<bool> updatePassword(String newPassword) =>
      _c.profileService.updatePassword(newPassword);

  /// Re-authenticate the currently signed-in account before sensitive actions.
  /// Uses the real Supabase credential rather than a client-generated OTP.
  Future<bool> reauthenticateWithPassword(String password) async {
    final email = _supabaseUser?.email?.trim();
    final currentId = _supabaseUser?.id;
    if (email == null || email.isEmpty || currentId == null || password.isEmpty) {
      return false;
    }

    try {
      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      return result['success'] == true &&
          (result['user'] as User?)?.id == currentId;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_supabaseUser == null) return false;
    _isLoading = true;
    notifyListeners();
    final updated = await _c.profile.updateProfile(
      authUser: _supabaseUser,
      currentUserModel: _userModel,
      userType: _form.userType,
      data: data,
    );
    if (updated != null) _userModel = updated;
    _isLoading = false;
    notifyListeners();
    return updated != null;
  }

  Future<bool> completeOwnerRegistration({
    required String verificationStatus,
  }) async {
    final model = await _c.account.completeOwnerRegistration(
      authUser: _supabaseUser,
      currentUserModel: _userModel,
      verificationStatus: verificationStatus,
    );
    if (model != null) {
      _userModel = model;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> toggleFavoriteStadium(String stadiumId) async {
    if (_userModel == null) return;
    final updated = await _c.profile.toggleFavoriteStadium(
      authUser: _supabaseUser,
      currentUserModel: _userModel,
      userType: _form.userType,
      stadiumId: stadiumId,
    );
    if (updated != null) {
      _userModel = updated;
      notifyListeners();
    }
  }

  Future<void> updateProfilePhoto(XFile file) async {
    if (_supabaseUser == null) return;
    await _runAuthAction(() async {
      final res = await _c.profile.updateProfilePhoto(
        authUser: _supabaseUser,
        currentUserModel: _userModel,
        file: file,
      );
      if (res.success && res.updatedModel != null) {
        _userModel = res.updatedModel;
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
    final res = await _c.account.completeSocialRegistration(
      firebaseUser: _supabaseUser,
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

  Future<bool> sendVerificationCode() =>
      _runAuthAction(() => _c.otp.sendVerificationCode(_form));

  Future<bool> verifyCode(String code) =>
      _runAuthAction(() async => _c.otp.verifyCode(_form, code));

  Future<bool> resetPassword(String email) =>
      _runAuthAction(() => _c.otp.resetPassword(email));

  Future<String?> determineGPSGovernorate({bool force = false}) async {
    final res = await _c.location.determineGPSGovernorate(force: force);
    if (res.error != null) _errorMessage = res.error;
    if (res.governorate != null) _form.governorate = res.governorate!;
    notifyListeners();
    return res.governorate;
  }

  Future<bool> updateUserLocation({bool force = false}) async {
    // RootScreen and PlayerHomeScreen can both request location during startup.
    // Serialize the operation so the OS permission dialog can never be triggered
    // concurrently by two startup paths.
    if (_locationUpdateInProgress) return false;
    _locationUpdateInProgress = true;
    try {
      final newGov = await determineGPSGovernorate(force: force);
      if (newGov != null &&
          _userModel != null &&
          _userModel!.governorate != newGov) {
        await updateProfile({'governorate': newGov});
        return true;
      }
      return newGov != null;
    } finally {
      _locationUpdateInProgress = false;
    }
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
      final res = await _c.profile.deleteAccount(currentUserModel: _userModel);
      if (res.success) await signOut();
      return res;
    });
  }

  Future<bool> verifyOtp({required String email, required String token}) =>
      _runAuthAction(() async {
        final res = await _c.otp.verifyOtp(email: email, token: token);
        if (res.success) {
          _supabaseUser = _authService.currentUser;
          if (_supabaseUser != null) await _fetchUserData(_supabaseUser!);
        }
        return res;
      });

  Future<bool> resendOtp() => _c.otp.resendOtp();

  @override
  void dispose() {
    _authSubscription?.cancel();
    _c.realtime.dispose();
    super.dispose();
  }

  Future<bool> payRehabilitationFine() => _runAuthAction(() async {
    final res = await _c.profile.payRehabilitationFine(authUser: _supabaseUser);
    if (res.success && _userModel != null) {
      _userModel = _userModel!.copyWith(noShowCount: 0, isBlocked: false);
    }
    return res;
  });
}
