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
  TournamentRosterCoordinator get rosterCoord =>
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

      // Atomic server function to enforce Phase Engine, capacity, membership, roster, and zero-trust entry
      final rpcRes = await _supabase.rpc('join_championship_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
        'p_player_ids': selectedPlayerIds,
        'p_guest_names': offlineGuestNames,
      });

      if (rpcRes is! Map || rpcRes['success'] != true) {
        final err = rpcRes is Map ? (rpcRes['error'] ?? rpcRes['message'])?.toString() : 'فشل الانضمام للبطولة.';
        throw Exception(err ?? 'فشل الانضمام للبطولة.');
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
    List<String> playerIds = const [],
    List<String> guestNames = const [],
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? 'ord_idem_${championshipId}_${teamId}_${DateTime.now().millisecondsSinceEpoch}';
      final res = await _supabase.rpc('create_tournament_order_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
        'p_player_ids': playerIds,
        'p_guest_names': guestNames,
        'p_idempotency_key': key,
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
  ///
  /// [H-04]: This is an authoritative server-side RPC operation.
  /// If [remove_tournament_team_atomic] fails, the operation fails.
  /// Callers receive a typed [TournamentCommandResult] with explicit error code.
  /// No semantic fallback to a different operation (leaveChampionship/refund) is permitted.
  Future<TournamentCommandResult> removeTournamentTeam(
    String championshipId,
    String teamId,
  ) async {
    try {
      final res = await _supabase.rpc('remove_tournament_team_atomic', params: {
        'p_championship_id': championshipId,
        'p_team_id': teamId,
      });

      if (res is Map && res['success'] == true) {
        return TournamentCommandResult.success();
      }

      final errorCode = res is Map ? (res['error_code']?.toString() ?? TournamentErrorCode.unknown) : TournamentErrorCode.unknown;
      final message = res is Map ? (res['error'] ?? res['message'])?.toString() : null;
      return TournamentCommandResult.failure(
        code: errorCode,
        message: message ?? 'فشل إزالة الفريق من البطولة.',
      );
    } on PostgrestException catch (e) {
      return TournamentCommandResult.failure(
        code: e.code ?? TournamentErrorCode.rpcError,
        message: e.message,
      );
    } catch (e) {
      debugPrint('removeTournamentTeam error: $e');
      return TournamentCommandResult.failure(
        code: TournamentErrorCode.unknown,
        message: e.toString(),
      );
    }
  }
}

/// Canonical result type for tournament command operations.
/// [H-04], [H-05]: Replaces boolean/null returns with structured result.
class TournamentCommandResult {
  final bool isSuccess;
  final String? errorCode;
  final String? errorMessage;

  const TournamentCommandResult._({
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
  });

  factory TournamentCommandResult.success() =>
      const TournamentCommandResult._(isSuccess: true);

  factory TournamentCommandResult.failure({
    required String code,
    String? message,
  }) =>
      TournamentCommandResult._(
        isSuccess: false,
        errorCode: code,
        errorMessage: message,
      );

  bool get isFailure => !isSuccess;

  @override
  String toString() =>
      isSuccess ? 'TournamentCommandResult(success)' : 'TournamentCommandResult(failure: $errorCode — $errorMessage)';
}

/// Canonical tournament error codes. [H-05]
abstract final class TournamentErrorCode {
  static const String unknown = 'TOURNAMENT_UNKNOWN_ERROR';
  static const String rpcError = 'TOURNAMENT_RPC_ERROR';
  static const String notFound = 'TOURNAMENT_NOT_FOUND';
  static const String conflict = 'TOURNAMENT_CONFLICT';
  static const String unauthorized = 'TOURNAMENT_UNAUTHORIZED';
  static const String invalidState = 'TOURNAMENT_INVALID_STATE';
  static const String capacityExceeded = 'TOURNAMENT_CAPACITY_EXCEEDED';
  static const String paymentRequired = 'TOURNAMENT_PAYMENT_REQUIRED';
}

