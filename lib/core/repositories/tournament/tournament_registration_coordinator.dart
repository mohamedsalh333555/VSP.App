import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/notification_handler.dart';
import '../team_repository.dart';
import 'tournament_roster_coordinator.dart';

/// Coordinates tournament registration, team joining, withdrawals, orders, and payment tracking.
class TournamentRegistrationCoordinator {
  final SupabaseClient? _client;
  final TeamRepository? _teamRepository;
  final TournamentRosterCoordinator? _rosterCoordinator;

  TournamentRegistrationCoordinator({
    SupabaseClient? client,
    TeamRepository? teamRepository,
    TournamentRosterCoordinator? rosterCoordinator,
  })  : _client = client,
        _teamRepository = teamRepository,
        _rosterCoordinator = rosterCoordinator;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  TeamRepository get _teamRepo => _teamRepository ?? TeamRepository();
  TournamentRosterCoordinator get _rosterCoord =>
      _rosterCoordinator ?? TournamentRosterCoordinator(client: _client, teamRepository: _teamRepo);

  /// Registers a team into a championship with atomic RPC and roster syncing.
  Future<bool> joinChampionship(
    String championshipId,
    String teamId, {
    List<String> selectedPlayerIds = const [],
    List<String> offlineGuestNames = const [],
    bool skipMemberCheck = false,
    bool isPaid = false,
    double? totalPaidAmount,
  }) async {
    try {
      final team = await _teamRepo.getTeam(teamId);
      if (team == null) throw Exception('المجموعة لا توجد.');

      final champResponse = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champResponse == null) throw Exception('البطولة لا توجد.');

      final champ = Championship.fromFirestore(champResponse, championshipId);

      if (!skipMemberCheck) {
        final totalRoster =
            selectedPlayerIds.length + offlineGuestNames.length;
        if (totalRoster < champ.minPlayersPerTeam) {
          throw Exception(
            'يجب أن تضم تشكيلة الفريق ${champ.minPlayersPerTeam} لاعبين على الأقل للمشاركة.',
          );
        }
        if (totalRoster > champ.maxPlayersPerTeam) {
          throw Exception(
            'تجاوزت تشكيلة الفريق الحد الأقصى للاعبين (${champ.maxPlayersPerTeam}).',
          );
        }
      }

      // Atomic server function to bypass RLS restrictions
      final rpcRes = await _supabase.rpc('join_championship_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
        'p_is_paid': isPaid,
      });

      if (rpcRes is Map && rpcRes['success'] == false) {
        throw Exception(rpcRes['message']?.toString() ?? 'فشل الانضمام للبطولة.');
      }

      // Save team roster
      try {
        await _rosterCoord.updateSingleTeamRoster(
          championshipId: championshipId,
          teamId: teamId,
          playerIds: selectedPlayerIds,
          guestNames: offlineGuestNames,
        );
      } catch (rosterErr) {
        debugPrint('Roster sync notice: $rosterErr');
      }

      // Alert championship owner
      if (champ.ownerId.isNotEmpty) {
        try {
          await NotificationHandler.notifyTeamJoinedTournament(
            ownerId: champ.ownerId,
            teamName: team.name,
            tournamentName: champ.name,
            championshipId: championshipId,
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error joining championship: $e');
      rethrow;
    }
  }

  Future<bool> verifyTournamentOrderPaid({
    required String orderReference,
  }) async {
    try {
      for (var attempt = 0; attempt < 18; attempt++) {
        final row = await _supabase
            .from('tournament_orders')
            .select('payment_status')
            .eq('order_reference', orderReference)
            .maybeSingle();
        if (row == null) {
          throw StateError('Tournament payment order was not found.');
        }

        final status = row['payment_status']?.toString();
        if (status == 'paid') return true;
        if (status != 'pending') {
          throw StateError('Tournament payment was not confirmed by the server.');
        }

        if (attempt < 17) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error verifying tournament order payment: $e');
      rethrow;
    }
  }

  /// Create tournament payment order in the database via atomic RPC.
  Future<Map<String, dynamic>?> createTournamentOrder({
    required String championshipId,
    required String teamId,
    required double amount,
    List<String> playerIds = const [],
    List<String> guestNames = const [],
  }) async {
    try {
      final res = await _supabase.rpc('create_tournament_order_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
        'p_player_ids': playerIds,
        'p_guest_names': guestNames,
        'p_amount': amount,
      });
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      throw StateError(res is Map ? (res['error']?.toString() ?? 'Failed to create tournament order.') : 'Failed to create tournament order.');
    } catch (e) {
      debugPrint('Error creating tournament order: $e');
      return null;
    }
  }

  /// Confirm tournament payment order with transaction ID via atomic RPC.
  Future<bool> confirmTournamentOrder({
    required String orderReference,
    required String paymobTransactionId,
  }) async {
    try {
      final res = await _supabase.rpc('confirm_tournament_order_atomic', params: {
        'p_order_reference': orderReference,
        'p_paymob_transaction_id': paymobTransactionId,
      });
      if (res is Map && res['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error confirming tournament order: $e');
      return false;
    }
  }

  /// Atomic team withdrawal from championship.
  Future<bool> leaveChampionship(String championshipId, String teamId) async {
    final result = await _supabase.rpc('leave_championship_atomic', params: {
      'p_championship_id': championshipId,
      'p_team_id': teamId,
    });
    if (result is Map && result['success'] == false) {
      throw StateError(result['error']?.toString() ?? 'Failed to leave championship.');
    }
    return true;
  }

  /// Removes a team from a tournament (by owner or admin).
  Future<bool> removeTournamentTeam(String championshipId, String teamId) async {
    final result = await _supabase.rpc('remove_tournament_team_atomic', params: {
      'p_championship_id': championshipId,
      'p_team_id': teamId,
    });
    if (result is Map && result['success'] == false) {
      throw StateError(result['error']?.toString() ?? 'Failed to remove tournament team.');
    }
    return true;
  }

  /// Toggle a team's paid status in a championship through an atomic server operation.
  Future<void> toggleTeamPayment({
    required String championshipId,
    required String teamId,
    required bool isPaid,
  }) async {
    final result = await _supabase.rpc('toggle_championship_team_payment_atomic', params: {
      'p_championship_id': championshipId,
      'p_team_id': teamId,
      'p_is_paid': isPaid,
    });
    if (result is Map && result['success'] == false) {
      throw StateError(result['error']?.toString() ?? 'Failed to update team payment status.');
    }
  }

  /// Check if 1v1 tournament order was paid.
  Future<bool> is1v1OrderPaid(String orderReference) async {
    try {
      final res = await _supabase
          .from('vsp_1v1_tournament_orders')
          .select('payment_status')
          .eq('order_reference', orderReference)
          .maybeSingle();
      return res != null && res['payment_status'] == 'paid';
    } catch (e) {
      debugPrint('Error checking 1v1 order paid status: $e');
      rethrow;
    }
  }
}
