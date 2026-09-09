import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import 'auth_user_data_fetcher.dart';

/// Coordinates fetching user session data, retry fetching, FCM registration, and notification listening.
class AuthSessionSyncCoordinator {
  final AuthUserDataFetcher? _userDataFetcherInstance;
  final NotificationService? _notificationServiceInstance;

  AuthSessionSyncCoordinator({
    AuthUserDataFetcher? userDataFetcher,
    NotificationService? notificationService,
  })  : _userDataFetcherInstance = userDataFetcher,
        _notificationServiceInstance = notificationService;

  AuthUserDataFetcher get _userDataFetcher =>
      _userDataFetcherInstance ?? AuthUserDataFetcher();
  NotificationService get notificationService =>
      _notificationServiceInstance ?? NotificationService();

  Future<UserDataFetchResult> fetchUserData({
    required User user,
    required String? currentUserType,
  }) {
    return _userDataFetcher.fetch(user: user, currentUserType: currentUserType);
  }

  Future<UserModel?> retryDataFetch(String uid) async {
    final res = await _userDataFetcher.retryDataFetch(uid);
    if (res.userModel != null) {
      await updateFcmToken(uid);
      return res.userModel;
    }
    return null;
  }

  Future<void> updateFcmToken(String uid) async {
    final token = await notificationService.getToken();
    await _userDataFetcher.updateFcmToken(uid, token);
  }

  void listenToRealtimeNotifications(String uid) {
    notificationService.listenToRealtimeNotifications(uid);
  }
}
