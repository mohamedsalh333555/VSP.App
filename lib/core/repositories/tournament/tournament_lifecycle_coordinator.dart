import 'dart:async';
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
      final stadiumId = data['stadiumId'] ?? data['stadium_id'];
      if (stadiumId == null) {
        throw Exception('يجب تحديد الملعب لإنشاء البطولة.');
      }

      final res = await _supabase.rpc('create_championship_atomic', params: {
        'p_name': data['name'] ?? '',
        'p_stadium_id': stadiumId,
        'p_type': TournamentPayloadBuilder.normalizeType((data['type'] ?? 'cup').toString()),
        'p_sport_type': (data['sportType'] ?? data['sport_type'] ?? 'football').toString().toLowerCase(),
        'p_entry_fee': num.tryParse(data['entryFee']?.toString() ?? data['entry_fee']?.toString() ?? '0') ?? 0,
        'p_grand_prize': num.tryParse(data['grandPrize']?.toString() ?? data['grand_prize']?.toString() ?? '0') ?? 0,
        'p_max_teams': int.tryParse(data['maxTeams']?.toString() ?? data['max_teams']?.toString() ?? '16') ?? 16,
        'p_min_players_per_team': int.tryParse(data['minPlayersPerTeam']?.toString() ?? data['min_players_per_team']?.toString() ?? '5') ?? 5,
        'p_max_players_per_team': int.tryParse(data['maxPlayersPerTeam']?.toString() ?? data['max_players_per_team']?.toString() ?? '11') ?? 11,
        'p_start_date': data['startDate'] is DateTime ? (data['startDate'] as DateTime).toIso8601String() : data['startDate']?.toString(),
        'p_end_date': data['endDate'] is DateTime ? (data['endDate'] as DateTime).toIso8601String() : data['endDate']?.toString(),
        'p_registration_closes_at': data['registrationClosesAt'] is DateTime 
            ? (data['registrationClosesAt'] as DateTime).toIso8601String() 
            : (data['registration_closes_at']?.toString() ?? (data['startDate'] is DateTime ? (data['startDate'] as DateTime).toIso8601String() : data['startDate']?.toString())),
        'p_rules': data['rules']?.toString() ?? '',
        'p_logo_url': data['logoUrl']?.toString() ?? data['logo_url']?.toString() ?? '',
        'p_currency': data['currency']?.toString() ?? 'EGP',
        'p_settings': data['settings'] is Map ? data['settings'] : {},
      });

      if (res is Map && res['success'] == true) {
        return res['championship_id']?.toString();
      }
      final errorMsg = res is Map ? (res['error'] ?? res['message'])?.toString() : 'Failed to create championship';
      throw Exception(errorMsg ?? 'Failed to create championship');
    } catch (e, stack) {
      VSPLogger.e('Error creating championship', e, stack);
      rethrow;
    }
  }

  /// Activates and publishes a championship for owner via atomic status transition.
  Future<bool> activateChampionship(String championshipId) async {
    try {
      final res = await _supabase.rpc(
        'transition_championship_status_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_new_status': 'open',
        },
      );
      if (res != null && res is Map && res['success'] == true) {
        VSPLogger.i('Championship $championshipId activated successfully.');
        return true;
      }
      final msg = res is Map ? (res['error'] ?? res['message'])?.toString() : 'Failed to activate championship';
      throw Exception(msg ?? 'Failed to activate championship');
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
  /// Server rejects explicitly if no allowed fields are modified.
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
      final msg = res is Map
          ? (res['message']?.toString() ?? res['code']?.toString() ?? 'Update blocked')
          : 'Update failed';
      VSPLogger.w('update_championship_atomic rejected: $res');
      throw Exception(msg);
    } catch (e, stack) {
      VSPLogger.e('Error updating championship', e, stack);
      rethrow;
    }
  }

  /// Transitions championship status atomically via transition_championship_status_atomic.
  /// Zero direct table updates or backdoors.
  Future<void> updateChampionshipStatus(
    String championshipId,
    String status,
  ) async {
    try {
      final res = await _supabase.rpc(
        'transition_championship_status_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_new_status': status,
        },
      );
      if (res != null && res is Map && res['success'] == true) {
        VSPLogger.i('Championship $championshipId transitioned to $status');
        return;
      }
      throw Exception(
        res is Map ? res['message']?.toString() : 'Failed to transition championship status',
      );
    } catch (e, stack) {
      VSPLogger.e('Error transitioning championship status to $status', e, stack);
      rethrow;
    }
  }

  /// Owner-initiated championship cancellation (routes through cancel_championship_atomic).
  /// Creates official refund obligations atomically in DB, then triggers async Paymob processing.
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
      if (res != null && res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      throw Exception(
        res is Map ? (res['error'] ?? res['message'])?.toString() : 'Cancellation failed',
      );
    } catch (e, stack) {
      VSPLogger.e('Error cancelling championship', e, stack);
      rethrow;
    }
  }

  /// Locks registration, cancels unpaid teams, and generates draw (transitions to draw_ready)
  Future<Map<String, dynamic>> startChampionship(String championshipId) async {
    try {
      final res = await _supabase.rpc(
        'start_championship_atomic',
        params: {'p_championship_id': championshipId},
      );
      if (res != null && res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      throw Exception(res is Map ? res['error']?.toString() : 'Failed to start championship');
    } catch (e, stack) {
      VSPLogger.e('Error in startChampionship', e, stack);
      rethrow;
    }
  }

  /// Activates competition kickoff (transitions from draw_ready to ongoing)
  Future<Map<String, dynamic>> activateCompetition(String championshipId) async {
    try {
      final res = await _supabase.rpc(
        'activate_championship_competition_atomic',
        params: {'p_championship_id': championshipId},
      );
      if (res != null && res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      throw Exception(res is Map ? res['error']?.toString() : 'Failed to activate competition');
    } catch (e, stack) {
      VSPLogger.e('Error in activateCompetition', e, stack);
      rethrow;
    }
  }

  /// Crowns champion team, awards badges, increments win counts, and sends celebration notifications via atomic server RPC.
  Future<void> crownChampion(
    String championshipId,
    String winningTeamId,
    String winningTeamName,
  ) async {
    try {
      final res = await _supabase.rpc('crown_tournament_champion_atomic', params: {
        'p_championship_id': championshipId,
        'p_champion_team_id': winningTeamId,
        'p_champion_team_name': winningTeamName,
      });

      if (res is Map && res['success'] != true) {
        throw Exception(res['error']?.toString() ?? 'Failed to crown champion');
      }

      try {
        await sendCelebrationNotifications(winningTeamId);
      } catch (notifErr) {
        debugPrint('Celebration notification side-effect failed, but DB crowning was already successful: $notifErr');
      }
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
    try {
      final res = await _supabase.rpc(
        'mark_championship_prize_delivered_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_notes': notes,
        },
      );
      if (res != null && res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      final msg = res is Map ? (res['error'] ?? res['message'])?.toString() : 'Failed to mark prize delivered';
      throw Exception(msg ?? 'Failed to mark prize delivered');
    } catch (e, s) {
      VSPLogger.e('Error marking championship prize delivered', e, s);
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
      throw Exception('Failed to get tournament financial summary');
    } catch (e, s) {
      VSPLogger.e('Error retrieving tournament financial summary', e, s);
      rethrow;
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
      if (res != null && res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      final msg = res is Map ? (res['error'] ?? res['message'])?.toString() : 'Failed to withdraw team';
      throw Exception(msg ?? 'Failed to withdraw team');
    } catch (e, s) {
      VSPLogger.e('Error withdrawing team from championship', e, s);
      rethrow;
    }