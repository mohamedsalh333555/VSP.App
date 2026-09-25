import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../repositories/notification_repository.dart';
import '../../services/logger_service.dart';
import '../../utils/phone_utils.dart';

/// Coordinator handling team member roster queries, additions, removals, and notifications.
class TeamRosterCoordinator {
  final SupabaseClient? _client;
  final NotificationRepository _notificationRepository;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  TeamRosterCoordinator({
    SupabaseClient? client,
    NotificationRepository? notificationRepository,
  })  : _client = client,
        _notificationRepository = notificationRepository ?? NotificationRepository(client: client);

  Future<List<String>> getTeamMemberUids(String teamId) async {
    final response = await _supabase
        .from('team_members')
        .select('user_id')
        .eq('team_id', teamId);
    return (response as List).map((row) => row['user_id'].toString()).toList();
  }

  Future<List<String>> getTeamPlayerImages(List<String> memberUids) async {
    if (memberUids.isEmpty) return [];
    final response = await _supabase
        .from('users')
        .select('profile_image_url')
        .inFilter('id', memberUids);
    return (response as List)
        .map((row) => row['profile_image_url']?.toString() ?? '')
        .toList();
  }

  /// Fetch list of player profiles (id, name, phone, position) for members of a team
  Future<List<Map<String, String>>> getTeamMemberProfiles(String teamId) async {
    try {
      final memberUids = await getTeamMemberUids(teamId);
      if (memberUids.isEmpty) return [];

      final response = await _supabase
          .from('users')
          .select('id, name, phone, position')
          .inFilter('id', memberUids);

      return (response as List).map((row) => {
        'uid': row['id']?.toString() ?? '',
        'name': row['name']?.toString() ?? 'Player',
        'phone': row['phone']?.toString() ?? '',
        'position': row['position']?.toString() ?? 'Player',
      }).toList();
    } catch (e) {
      debugPrint('Error getting team member profiles: $e');
      return [];
    }
  }

  Future<void> addMemberToTeam(String teamId, String userId, String imageUrl) async {
    final response = await _supabase.rpc('add_team_member_atomic', params: {'p_team_id': teamId, 'p_user_id': userId});
    if (response is! Map || response['success'] != true) {
      throw Exception(response is Map ? response['error'] ?? 'فشل إضافة اللاعب' : 'فشل إضافة اللاعب');
    }
    await sendJoinNotification(userId);
  }

  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) async {
    final response = await _supabase.rpc('remove_team_member_atomic', params: {'p_team_id': teamId, 'p_user_id': userId});
    if (response is! Map || response['success'] != true) {
      throw Exception(response is Map ? response['error'] ?? 'تعذر إزالة اللاعب' : 'تعذر إزالة اللاعب');
    }
  }
  Future<void> sendJoinNotification(String userId) async {
    try {
      await _notificationRepository.sendNotification(
        userId,
        AppNotification(
          id: '',
          title: " New Team Transfer!",
          body: "You have been drafted to join a new team. Get ready for the next match!",
          type: "info",
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Error sending join notification: $e');
    }
  }

  /// Stream user's membership changes
  Stream<List<Map<String, dynamic>>> streamUserMembership(String userId) {
    return _supabase
        .from('team_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .handleError((err) {
          VSPLogger.w('Membership realtime stream notice: $err');
        });
  }
}
