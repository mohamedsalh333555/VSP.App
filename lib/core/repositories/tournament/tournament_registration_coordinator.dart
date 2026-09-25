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

  /// Atomic team withdrawal from championship.
  Future<bool> leaveChampionship(String championshipId, String teamId) async {
    try {
      final response = await _supabase.functions.invoke(
        'process_tournament_refund',
        body: {
          'championship_id': championshipId,
          'team_id': teamId,
          'reason': 'انسحاب الفريق من البطولة',
        },
      );

      final data = response.data;
      if (data is Map && data['success'] == true) return true;

      final message = data is Map
          ? (data['message']?.toString() ?? 'تعذر تنفيذ انسحاب الفريق.')
          : 'تعذر تنفيذ انسحاب الفريق.';
      throw Exception(message);
    } catch (e) {
      debugPrint('Error in leaveChampionship: $e');
      return false;
    }
  }


  /// Removes a team from a tournament (by owner or admin).
  Future<bool> removeTournamentTeam(String championshipId, String teamId) async {
    try {
      try {
        await _supabase.rpc('remove_tournament_team_atomic', params: {
          'p_championship_id': championshipId,
          'p_team_id': teamId,
        });
        debugPrint(
          'Team $teamId removed via remove_tournament_team_atomic RPC.',
        );
        return true;
      } catch (rpcErr) {
        debugPrint('remove_tournament_team_atomic fallback: $rpcErr');
        return await leaveChampionship(championshipId, teamId);
      }
    } catch (e) {
      debugPrint('Error in removeTournamentTeam: $e');
      return false;
    }
  }

  /// Toggle a team's paid status in a championship.
  Future<void> toggleTeamPayment({
    required String championshipId,
    required String teamId,
    required bool isPaid,
  }) async {
    throw Exception('لا يمكن تعديل حالة الدفع يدويًا. حالة الدفع تُحدّث تلقائيًا بعد التحقق المالي.');
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
