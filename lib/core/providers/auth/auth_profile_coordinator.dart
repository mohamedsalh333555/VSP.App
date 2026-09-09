import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import 'auth_profile_service.dart';

/// Coordinates high-level profile mutations, photo uploads, and fines for AuthProvider.
class AuthProfileCoordinator {
  final AuthProfileService _profileService;

  AuthProfileCoordinator({AuthProfileService? profileService})
      : _profileService = profileService ?? AuthProfileService();

  Future<UserModel?> updateProfile({
    required User? authUser,
    required UserModel? currentUserModel,
    required String? userType,
    required Map<String, dynamic> data,
  }) async {
    if (authUser == null) return null;
    final res = await _profileService.updateProfile(
      authUser: authUser,
      currentUserModel: currentUserModel,
      userType: userType,
      data: data,
    );
    return res.success ? res.updatedModel : null;
  }

  Future<({bool success, String? error, UserModel? updatedModel})> updateProfilePhoto({
    required User? authUser,
    required UserModel? currentUserModel,
    required XFile file,
  }) async {
    if (authUser == null) return (success: false, error: null, updatedModel: null);
    final res = await _profileService.uploadProfilePhoto(
      authUser: authUser,
      currentUserModel: currentUserModel,
      file: file,
    );
    if (res.success && res.imageUrl != null) {
      UserModel? updated = currentUserModel?.copyWith(profileImageUrl: res.imageUrl);
      final updateRes = await _profileService.updateProfile(
        authUser: authUser,
        currentUserModel: currentUserModel,
        userType: currentUserModel?.role,
        data: {'profileImageUrl': res.imageUrl},
      );
      if (updateRes.success && updateRes.updatedModel != null) {
        updated = updateRes.updatedModel;
      }
      return (success: true, error: null, updatedModel: updated);
    }
    return (success: res.success, error: res.error, updatedModel: null);
  }

  Future<UserModel?> toggleFavoriteStadium({
    required User? authUser,
    required UserModel? currentUserModel,
    required String? userType,
    required String stadiumId,
  }) async {
    if (currentUserModel == null || authUser == null) return null;
    final list = _profileService.toggleFavoriteStadiumList(
      currentFavorites: currentUserModel.favoriteStadiums,
      stadiumId: stadiumId,
    );
    return updateProfile(
      authUser: authUser,
      currentUserModel: currentUserModel,
      userType: userType,
      data: {'favoriteStadiums': list},
    );
  }

  Future<({bool success, String? error})> payRehabilitationFine({
    required User? authUser,
  }) async {
    if (authUser == null) return (success: false, error: null);
    final ok = await _profileService.payRehabilitationFine(authUser.id);
    return (success: ok, error: ok ? null : 'فشل سداد الغرامة');
  }

  Future<({bool success, String? error})> deleteAccount({
    required UserModel? currentUserModel,
  }) async {
    if (currentUserModel == null) return (success: false, error: null);
    final res = await _profileService.deleteAccount(currentUserModel);
    return (success: res.success, error: res.error);
  }
}
