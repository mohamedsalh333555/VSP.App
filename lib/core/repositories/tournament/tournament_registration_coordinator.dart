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
      return null;
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

  /// Finalizes a previously paid tournament order without attempting a second
  /// paid-join mutation. The Paymob webhook is responsible for adding the team;
  /// this method only verifies the paid order, syncs the roster, and notifies
  /// the championship owner.
  Future<bool> finalizePaidTournamentRegistration({
    required String orderReference,
    required String championshipId,
    required String teamId,
    required List<String> selectedPlayerIds,
    required List<String> offlineGuestNames,
  }) async {
    try {
      final callerId = _supabase.auth.currentUser?.id;
      if (callerId == null) return false;

      final order = await _supabase
          .from('tournament_orders')
          .select('championship_id, team_id, captain_user_id, payment_status')
          .eq('order_reference', orderReference)
          .maybeSingle();

      if (order == null ||
          order['championship_id']?.toString() != championshipId ||
          order['team_id']?.toString() != teamId ||
          order['captain_user_id']?.toString() != callerId ||
          order['payment_status']?.toString() != 'paid') {
        return false;
      }

      final team = await _teamRepo.getTeam(teamId);
      if (team == null) return false;

      final champResponse = await _supabase
          .from('championships')
          .select('id, owner_id, name')
          .eq('id', championshipId)
          .maybeSingle();
      if (champResponse == null) return false;

      await _rosterCoord.updateSingleTeamRoster(
        championshipId: championshipId,
        teamId: teamId,
        playerIds: selectedPlayerIds,
        guestNames: offlineGuestNames,
      );

      final ownerId = champResponse['owner_id']?.toString() ?? '';
      if (ownerId.isNotEmpty) {
        try {
          await NotificationHandler.notifyTeamJoinedTournament(
            ownerId: ownerId,
            teamName: team.name,
            tournamentName: champResponse['name']?.toString() ?? 'البطولة',
            championshipId: championshipId,
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Error finalizing paid tournament registration: $e');
      return false;
    }
  }

  /// Atomic team withdrawal from championship.
  Future<bool> leaveChampionship(String championshipId, String teamId) async {
    try {
      final response = await _supabase.rpc('leave_championship_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
      });
      if (response is Map && response['success'] == false) {
        debugPrint('leave_championship_atomic rejected: ${response['error']}');
        return false;
      }
      debugPrint(
        'Team $teamId left championship $championshipId via leave_championship_atomic RPC.',
      );
      return true;
    } catch (e) {
      debugPrint('Error in leaveChampionship atomic RPC: $e');
      return false;
    }
  }

  /// Removes a team from a tournament (by owner or admin).
  Future<bool> removeTournamentTeam(String championshipId, String teamId) async {
    try {
      final response =
          await _supabase.rpc('remove_tournament_team_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
      });
      if (response is Map && response['success'] == false) {
        debugPrint('remove_tournament_team_atomic rejected: ${response['error']}');
        return false;
      }
      debugPrint(
        'Team $teamId removed via remove_tournament_team_atomic RPC.',
      );
      return true;
    } catch (e) {
      debugPrint('Error in removeTournamentTeam atomic RPC: $e');
      return false;
    }
  }

  /// Toggle a team's paid status in a championship.
  Future<void> toggleTeamPayment({
    required String championshipId,
    required String teamId,
    required bool isPaid,
  }) async {
    try {
      final response =
          await _supabase.rpc('toggle_championship_team_payment_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
        'p_is_paid': isPaid,
      });
      if (response is Map && response['success'] == false) {
        throw Exception(response['error']?.toString() ?? 'فشل تحديث حالة الدفع.');
      }
    } catch (e) {
      debugPrint('Error toggling team payment atomically: $e');
      rethrow;
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
      return false;
    }
  }
}
