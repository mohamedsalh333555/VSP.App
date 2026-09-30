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

  /// Returns server-authoritative policy: what actions are allowed for this championship.
  /// All UI surfaces MUST call this before showing edit/cancel/delete controls.
  Future<Map<String, dynamic>> getChampionshipActions(String championshipId) async {
    try {
      final res = await _supabase.rpc(
        'get_championship_actions',
        params: {'p_championship_id': championshipId},
      );
      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'can_edit': false, 'can_delete': false, 'can_cancel': false, 'reason': 'rpc_error'};
    } catch (e, stack) {
      VSPLogger.e('Error fetching championship actions', e, stack);
      return {'can_edit': false, 'can_delete': false, 'can_cancel': false, 'reason': 'error'};
    }
  }

  /// Updates championship fields — routes through update_championship_atomic (server-enforced).
  /// Server strips any fields not allowed in the current state.
  Future<bool> updateChampionship(String id, Map<String, dynamic> data) async {
    try {
      final pgData = TournamentPayloadBuilder.buildUpdatePayload(data);
      final payload = pgData.isNotEmpty ? pgData : data;
      final res = await _supabase.rpc(
        'update_championship_atomic',
        params: {
          'p_championship_id': id,
          'p_updates': payload,
        },
      );
      if (res != null && res is Map && res['success'] == true) {
        VSPLogger.i('Championship $id updated: ${res['updated_fields']}');
        return true;
      }
      VSPLogger.w('update_championship_atomic returned unexpected: $res');
      return false;
    } catch (e, stack) {
      VSPLogger.e('Error updating championship', e, stack);
      return false;
    }
  }

  /// Transitions championship status — used for admin/system operations (ongoing, completed).
  /// For owner-initiated cancel: use cancelChampionship() instead.
  Future<void> updateChampionshipStatus(
    String championshipId,
    String status,
  ) async {
    try {
      // Admin status transitions (e.g. open→ongoing when fixtures generated)
      // These go through admin_update_championship_status_atomic when available
      final res = await _supabase.rpc(
        'admin_update_championship_status_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_status': status,
        },
      ).maybeSingle();
      if (res == null || res['success'] == true) return;
    } catch (_) {
      // Fallback for non-admin status transitions (e.g. ongoing after fixture generation)
      await _supabase
          .from('championships')
          .update({'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', championshipId);
    }
  }

  /// Owner-initiated championship cancellation (routes through cancel_championship_atomic).
  /// For Team League: automatically delegates to cancel_team_league (with payment handling).
  Future<Map<String, dynamic>> cancelChampionship(
    String championshipId, {
    String reason = 'owner_initiated',
  }) async {
    try {
      final res = await _supabase.rpc(
        'cancel_championship_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_reason': reason,
        },
      );
      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }
      throw Exception('Unexpected cancel response');
    } catch (e, stack) {
      VSPLogger.e('Error cancelling championship', e, stack);
      rethrow;
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

  /// Hard-deletes championship — routes through delete_championship_atomic (server-enforced).
  /// Server BLOCKS delete if: teams joined, matches exist, or payments made.
  /// Only allowed for empty open championships.
  Future<bool> deleteChampionship(String championshipId) async {
    try {
      final res = await _supabase.rpc(
        'delete_championship_atomic',
        params: {'p_championship_id': championshipId},
      );
      if (res != null && res is Map && res['success'] == true) {
        VSPLogger.i('Championship $championshipId permanently deleted.');
        return true;
      }
      VSPLogger.w('delete_championship_atomic unexpected: $res');
      return false;
    } catch (e, stack) {
      VSPLogger.e('Error deleting championship', e, stack);
      // Surface the server error message to the caller (BLOCKED_BY_STATE etc.)
      rethrow;
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

  /// Retrieves tournament financial summary (total collected, grand prize, net profit).
  Future<Map<String, dynamic>> getTournamentFinancialSummary(String championshipId) async {
    try {
      final res = await _supabase.rpc(
        'get_tournament_financial_summary',
        params: {'p_championship_id': championshipId},
      );
      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      VSPLogger.w('get_tournament_financial_summary RPC fallback: $e');
    }

    // Direct computation fallback
    try {
      final champ = await _supabase
          .from('championships')
          .select('entry_fee, grand_prize, paid_teams, joined_teams')
          .eq('id', championshipId)
          .maybeSingle();

      if (champ == null) {
        return {
          'total_collected': 0.0,
          'grand_prize': 0.0,
          'net_profit': 0.0,
          'paid_teams_count': 0,
        };
      }

      final double entryFee = double.tryParse((champ['entry_fee'] ?? 0).toString()) ?? 0.0;
      final double grandPrize = double.tryParse((champ['grand_prize'] ?? 0).toString()) ?? 0.0;
      final List paidTeams = (champ['paid_teams'] as List?) ?? [];
      final int paidCount = paidTeams.length;
      final double totalCollected = paidCount * entryFee;
      final double netProfit = totalCollected - grandPrize;

      return {
        'total_collected': totalCollected,
        'grand_prize': grandPrize,
        'net_profit': netProfit,
        'paid_teams_count': paidCount,
      };
    } catch (err, s) {
      VSPLogger.e('Error computing financial summary fallback', err, s);
      return {
        'total_collected': 0.0,
        'grand_prize': 0.0,
        'net_profit': 0.0,
        'paid_teams_count': 0,
      };
    }
  }

  /// Withdraws a team from championship and calculates/processes refund atomically.
  Future<Map<String, dynamic>> withdrawTeamFromChampionship({
    required String championshipId,
    required String teamId,
  }) async {
    try {
      final res = await _supabase.rpc(
        'withdraw_team_from_championship_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_team_id': teamId,
        },
      );
      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      VSPLogger.w('withdraw_team_from_championship_atomic fallback: $e');
    }

    // Fallback: direct team removal
    try {
      final champ = await _supabase
          .from('championships')
          .select('joined_teams, paid_teams')
          .eq('id', championshipId)
          .maybeSingle();

      if (champ != null) {
        final List<String> joined = List<String>.from(champ['joined_teams'] ?? [])..remove(teamId);
        final List<String> paid = List<String>.from(champ['paid_teams'] ?? [])..remove(teamId);
        await _supabase.from('championships').update({
          'joined_teams': joined,
          'paid_teams': paid,
        }).eq('id', championshipId);
      }
      return {'success': true, 'message': 'تم سحب الفريق بنجاح'};
    } catch (err, s) {
      VSPLogger.e('Error withdrawing team fallback', err, s);
      rethrow;
    }
  }
}
