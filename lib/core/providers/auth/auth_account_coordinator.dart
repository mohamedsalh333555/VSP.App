import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import 'auth_oauth_coordinator.dart';
import 'auth_registration_form_state.dart';
import 'auth_registration_service.dart';

/// Coordinates account creation, authentication, and social registration workflows for AuthProvider.
class AuthAccountCoordinator {
  final AuthRegistrationService? _registrationServiceInstance;
  final AuthOAuthCoordinator? _oauthCoordinatorInstance;

  AuthAccountCoordinator({
    AuthRegistrationService? registrationService,
    AuthOAuthCoordinator? oauthCoordinator,
  })  : _registrationServiceInstance = registrationService,
        _oauthCoordinatorInstance = oauthCoordinator;

  AuthRegistrationService get _registrationService =>
      _registrationServiceInstance ?? AuthRegistrationService();
  AuthOAuthCoordinator get _oauthCoordinator =>
      _oauthCoordinatorInstance ?? AuthOAuthCoordinator();

  Future<({bool success, String? error, UserModel? userModel})> createAccount({
    required User? currentUser,
    required UserModel? currentUserModel,
    required AuthRegistrationFormState form,
  }) async {
    final res = await _registrationService.createAccount(
      currentUser: currentUser,
      currentUserModel: currentUserModel,
      password: form.password,
      name: form.name,
      phone: form.phone,
      position: form.position,
      userType: form.userType,
    );
    return (success: res.success, error: res.error, userModel: res.userModel);
  }

  Future<({bool success, String? error, User? user})> signInWithGoogle({
    bool isLoginOnly = false,
    String? userType,
  }) async {
    final res = await _oauthCoordinator.signInWithGoogle(isLoginOnly: isLoginOnly, userType: userType);
    return (success: res.success, error: res.error, user: res.user);
  }

  Future<({bool success, String? error, User? user})> signInWithApple({
    bool isLoginOnly = false,
    String? userType,
  }) async {
    final res = await _oauthCoordinator.signInWithApple(isLoginOnly: isLoginOnly, userType: userType);
    return (success: res.success, error: res.error, user: res.user);
  }

  Future<({bool success, String? error, User? user, UserModel? userModel})> signUp({
    required String email,
    required String password,
    required String role,
    required String governorate,
    Map<String, dynamic>? userData,
  }) async {
    final res = await _registrationService.signUp(
      email: email,
      password: password,
      role: role,
      governorate: governorate,
      userData: userData,
    );
    return (success: res.success, error: res.error, user: res.user, userModel: res.userModel);
  }

  Future<({bool success, String? error, User? user, UserModel? userModel})> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _registrationService.signIn(email: email, password: password);
    return (success: res.success, error: res.error, user: res.user, userModel: res.userModel);
  }

  Future<void> abortRegistration({
    required User? user,
    required UserModel? userModel,
  }) async {
    await _registrationService.abortRegistration(user, userModel);
  }

  Future<UserModel?> completeOwnerRegistration({
    required User? authUser,
    required UserModel? currentUserModel,
    required String verificationStatus,
  }) async {
    final res = await _registrationService.completeOwnerRegistration(
      authUser: authUser,
      currentUserModel: currentUserModel,
      verificationStatus: verificationStatus,
    );
    return res.success ? res.userModel : null;
  }

  Future<({bool success, String? error, UserModel? userModel})> completeSocialRegistration({
    required User? firebaseUser,
    required UserModel? currentUserModel,
    required String? userType,
    required String fallbackGovernorate,
    required String phone,
    String? name,
    String? position,
    String? governorate,
    DateTime? dateOfBirth,
    String? p2pInstapay,
    String? p2pVodafone,
    String? p2pBank,
  }) async {
    final res = await _oauthCoordinator.completeSocialRegistration(
      firebaseUser: firebaseUser,
      currentUserModel: currentUserModel,
      userType: userType,
      fallbackGovernorate: fallbackGovernorate,
      phone: phone,
      name: name,
      position: position,
      governorate: governorate,
      dateOfBirth: dateOfBirth,
      p2pInstapay: p2pInstapay,
      p2pVodafone: p2pVodafone,
      p2pBank: p2pBank,
    );
    return (success: res.success, error: res.error, userModel: res.userModel);
  }
}
