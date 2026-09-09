import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../services/logger_service.dart';

/// Manages real-time Supabase postgres change subscriptions for the current user profile.
class AuthRealtimeCoordinator {
  final SupabaseClient? _client;
  RealtimeChannel? _userChannel;
  final StreamController<void> _celebrationController = StreamController<void>.broadcast();

  AuthRealtimeCoordinator({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Stream<void> get celebrationEvents => _celebrationController.stream;

  /// Starts real-time Postgres change listener for user's row in public.users.
  void startRealtimeUserListener({
    required String userId,
    required UserModel? Function() getUserModel,
    required User? Function() getFirebaseUser,
    required void Function(UserModel) onUserUpdated,
  }) {
    stopRealtimeUserListener();

    VSPLogger.i('Starting real-time subscription for user profile: $userId');
    _userChannel = _supabase
        .channel('public:users:id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            VSPLogger.i('Real-time update received for user profile: ${payload.newRecord}');
            final newRecord = payload.newRecord;
            final currentModel = getUserModel();
            if (newRecord.isNotEmpty && currentModel != null) {
              var newModel = UserModel.fromFirestore(newRecord);

              final authUser = getFirebaseUser();
              if (authUser?.emailConfirmedAt != null && !newModel.isEmailVerified) {
                newModel = newModel.copyWith(isEmailVerified: true);
              }

              final oldStatus = currentModel.verificationStatus;
              final newStatus = newModel.verificationStatus;

              onUserUpdated(newModel);

              if ((oldStatus == 'pending' || oldStatus == null) && newStatus == 'approved') {
                VSPLogger.i('Owner approved! Triggering celebration events.');
                _celebrationController.add(null);
              }
            }
          },
        );
    _userChannel!.subscribe();
  }

  /// Unsubscribes and tears down existing real-time channel.
  void stopRealtimeUserListener() {
    if (_userChannel != null) {
      VSPLogger.i('Stopping real-time subscription for user profile');
      _userChannel?.unsubscribe();
      try {
        _supabase.removeChannel(_userChannel!);
      } catch (_) {}
      _userChannel = null;
    }
  }

  /// Closes stream controller and cleans up listener.
  void dispose() {
    stopRealtimeUserListener();
    _celebrationController.close();
  }
}
