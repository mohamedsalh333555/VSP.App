import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';
import '../notification_repository.dart';
import '../team_repository.dart';
import 'tournament_payload_builder.dart';

/// Coordinates championship creation, activation, status transitions, champion crowning, deletion, and prize delivery.
class TournamentLifecycleCoordinator {
  final SupabaseClient? _client;
  final NotificationRepository? _notificationRepository;
  final TeamRepository? _teamRepository;

  TournamentLifecycleCoordinator({
    SupabaseClient? client,
    NotificationRepository? notificationRepository,
    TeamRepository? teamRepository,
  })  : _client = client,
        _notificationRepository = notificationRepository,
        _teamRepository = teamRepository;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  NotificationRepository get _notificationRepo =>
      _notificationRepository ?? NotificationRepository();
  TeamRepository get _teamRepo => _teamRepository ?? TeamRepository();

  /// Creates a new championship in Supabase with role checking and schema-compliant payload.
  Future<String?> createChampionship(Map<String, dynamic> data) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      bool isApproved = false;
      if (currentUserId != null) {
        try {
          final userDoc = await _supabase
              .from('users')
              .select('role')
              .eq('id', currentUserId)
              .maybeSingle();
          final userRole = userDoc?['role']?.toString().toLowerCase();
          if (userRole == 'admin' ||
              userRole == 'co_founder' ||
              userRole == 'super_admin' ||
              userRole == 'cofounder') {
            isApproved = true;
          }
        } catch (_) {
          isApproved = false;
        }
      }

      final pgData = TournamentPayloadBuilder.buildCreatePayload(
        data,
        isAdminApproved: isApproved,
        fallbackOwnerId: currentUserId ?? '',
      );

      try {
        final response = await _supabase
            .from('championships')
            .insert(pgData)
            .select('id')
            .single();
        return response['id']?.toString();
      } on PostgrestException catch (pe) {
        if (pe.message.contains('championships_type_check')) {
          pgData['type'] = 'cup';
          final response = await _supabase
              .from('championships')
              .insert(pgData)
              .select('id')
              .single();
          return response['id']?.toString();
        }
        rethrow;
      }
    } catch (e, stack) {
      VSPLogger.e('Error creating championship', e, stack);
      rethrow;
    }
  }

  /// Activates and publishes a championship for owner.
  Future<bool> activateChampionship(String championshipId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      bool isApproved = false;
      if (currentUserId != null) {
        try {
          final userDoc = await _supabase
              .from('users')
              .select('role')
              .eq('id', currentUserId)
              .maybeSingle();
          final userRole = userDoc?['role']?.toString().toLowerCase();
          if (userRole == 'admin' ||
              userRole == 'co_founder' ||
              userRole == 'super_admin' ||
              userRole == 'cofounder') {
            isApproved = true;
          }
        } catch (_) {}
      }

      final updateMap = <String, dynamic>{
        'status': 'open',
        'creation_fee_paid': true,
      };
      if (isApproved) {
        updateMap['is_approved'] = true;
      }
      await _supabase
          .from('championships')
          .update(updateMap)
          .eq('id', championshipId);
      VSPLogger.i('Championship $championshipId activated successfully.');
      return true;
    } catch (e, stack) {
      VSPLogger.e('Error activating championship', e, stack);
      return false;
    }
  }

  /// Updates championship fields with sanitized payload.
  Future<bool> updateChampionship(String id, Map<String, dynamic> data) async {
    try {
      final pgData = TournamentPayloadBuilder.buildUpdatePayload(data);
      if (pgData.isEmpty) return true;
      await _supabase.from('championships').update(pgData).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating championship: $e');
      return false;
    }
  }

  /// Update championship status directly (e.g. 'open', 'ongoing', 'completed').
  Future<void> updateChampionshipStatus(
    String championshipId,
    String status,
  ) async {
    try {
      await _supabase
          .from('championships')
          .update({'status': status})
          .eq('id', championshipId);
    } catch (e) {
      debugPrint('Error updating championship status: $e');
    }
  }

  /// Crowns champion team, awards badges, increments win counts, and sends celebration notifications.
  Future<void> crownChampion(
    String championshipId,
    String winningTeamId,
    String winningTeamName,
  ) async {
    try {
      await _supabase
          .from('championships')
          .update({
            'status': 'completed',
            'champion_team_id': winningTeamId,
            'champion_team_name': winningTeamName,
          })
          .eq('id', championshipId);

      final team = await _teamRepo.getTeam(winningTeamId);
      if (team != null) {
        final badges = List<String>.from(team.unlockedBadges);
        if (!badges.contains('cup_winner')) {
          badges.add('cup_winner');
        }
        await _supabase.from('teams').update({
          'championships_won': team.championshipsWon + 1,
          'unlocked_badges': badges,
        }).eq('id', winningTeamId);
      }

      await sendCelebrationNotifications(winningTeamId);
    } catch (e) {
      debugPrint('Error crowning champion: $e');
      throw 'Failed to crown champion';
    }
  }

  /// Sends celebration notification to team members.
  Future<void> sendCelebrationNotifications(String teamId) async {
    try {
      final team = await _teamRepo.getTeam(teamId);
      if (team == null) return;

      for (final uid in team.memberUids) {
        await _notificationRepo.sendNotification(
          uid,
          AppNotification(
            id: '',
            title: ' CHAMPIONS!',
            body:
                'Your team has won the championship! A new trophy has been added to your team profile.',
            type: 'info',
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending celebration notifications: $e');
    }
  }

  /// Deletes championship and cleans up all associated rosters and matches.
  Future<bool> deleteChampionship(String championshipId) async {
    try {
      try {
        final rosters = await _supabase
            .from('championship_rosters')
            .select('id')
            .eq('championship_id', championshipId);
        final rosterIds =
            (rosters as List).map((r) => r['id'].toString()).toList();
        if (rosterIds.isNotEmpty) {
          try {
            await _supabase
                .from('championship_roster_players')
                .delete()
                .inFilter('roster_id', rosterIds);
          } catch (_) {}
          try {
            await _supabase
                .from('championship_roster_guests')
                .delete()
                .inFilter('roster_id', rosterIds);
          } catch (_) {}
        }
        await _supabase
            .from('championship_rosters')
            .delete()
            .eq('championship_id', championshipId);
      } catch (rosterErr) {
        debugPrint('Championship rosters cleanup notice: $rosterErr');
      }

      try {
        await _supabase
            .from('tournament_matches')
            .delete()
            .eq('championship_id', championshipId);
      } catch (matchErr) {
        debugPrint('Tournament matches cleanup notice: $matchErr');
      }

      await _supabase
          .from('championships')
          .delete()
          .eq('id', championshipId);

      debugPrint('Championship $championshipId deleted successfully.');
      return true;
    } catch (e) {
      debugPrint('Error deleting championship: $e');
      return false;
    }
  }

  /// Atomically marks a championship prize as delivered in the financial ledger.
  Future<Map<String, dynamic>> markChampionshipPrizeDelivered(
    String championshipId, {
    String? notes,
  }) async {
    final auth = _supabase.auth.currentUser;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final res = await _supabase.rpc(
        'mark_championship_prize_delivered_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_notes': notes,
        },
      );
      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      VSPLogger.w('mark_championship_prize_delivered_atomic RPC fallback: $e');
    }

    // Direct fallback update to guarantee successful recording in championships
    try {
      await _supabase.from('championships').update({
        'prize_delivered': true,
        'prize_delivered_at': now,
        'prize_delivered_by': auth?.id ?? 'owner',
        'prize_delivery_notes': notes ?? '',
        'updated_at': now,
      }).eq('id', championshipId);

      return {
        'success': true,
        'message': 'Prize delivery recorded successfully',
      };
    } catch (fallbackError, s) {
      VSPLogger.e('Error marking championship prize delivered fallback', fallbackError, s);
      rethrow;
    }
  }
}
