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
    try {
      final memberUids = await getTeamMemberUids(teamId);
      if (memberUids.length >= 12) {
        throw Exception("تنبيه: عذراً، اكتمل الحد الأقصى لأعضاء الفريق (12 لاعباً كحد أقصى).");
      }

      final userTeamMemberships = await _supabase
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId);
      if ((userTeamMemberships as List).length >= 3) {
        throw Exception("تنبيه: اللاعب وصل للحد الأقصى للانضمام للفرق (3 فرق كحد أقصى).");
      }

      await _supabase.from('team_members').insert({
        'team_id': teamId,
        'user_id': userId,
      });
      sendJoinNotification(userId);
    } on PostgrestException catch (e) {
      if (e.message.contains('الحد الأقصى') || e.message.contains('limit') || e.message.contains('12')) {
        throw Exception("تنبيه: اللاعب وصل للحد الأقصى للانضمام للفرق (3 فرق كحد أقصى) أو الفريق اكتمال (12 لاعباً).");
      }
      rethrow;
    } catch (e) {
      debugPrint('Error adding member to team: $e');
      rethrow;
    }
  }

  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final activeBookings = await _supabase
          .from('bookings')
          .select('id')
          .eq('status', 'confirmed')
          .or('player_team_id.eq.$teamId,opponent_team_id.eq.$teamId')
          .gt('end_time', nowIso)
          .limit(1);

      final bool hasActiveMatch = (activeBookings as List).isNotEmpty;

      final activeTournaments = await _supabase
          .from('championships')
          .select('id')
          .inFilter('status', ['open', 'ongoing'])
          .contains('joined_teams', [teamId]);
      final bool hasActiveTournament = (activeTournaments as List).isNotEmpty;

      if (hasActiveMatch || hasActiveTournament) {
        throw Exception("active_match_or_tournament_error");
      }

      // Automatic Captain Transfer: If the departing user is the captain, transfer to next member
      final teamData = await _supabase
          .from('teams')
          .select('captain_id')
          .eq('id', teamId)
          .maybeSingle();

      final String currentCaptainId = teamData?['captain_id']?.toString() ?? '';
      if (currentCaptainId == userId) {
        final allMembers = await getTeamMemberUids(teamId);
        final remainingMembers = allMembers.where((uid) => uid != userId).toList();

        if (remainingMembers.isNotEmpty) {
          final nextCaptainId = remainingMembers.first;
          final nextCaptainUser = await _supabase
              .from('users')
              .select('name, phone, profile_image_url')
              .eq('id', nextCaptainId)
              .maybeSingle();

          await _supabase.from('teams').update({
            'captain_id': nextCaptainId,
            'captain_name': nextCaptainUser?['name'] ?? 'Captain',
            'captain_phone': PhoneUtils.normalize(nextCaptainUser?['phone']?.toString() ?? ''),
            'captain_image_url': nextCaptainUser?['profile_image_url'] ?? '',
          }).eq('id', teamId);
        }
      }

      await _supabase
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error removing member from team: $e');
      rethrow;
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
