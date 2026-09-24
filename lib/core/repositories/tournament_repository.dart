import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import 'tournament/tournament_fixture_coordinator.dart';
import 'tournament/tournament_lifecycle_coordinator.dart';
import 'tournament/tournament_match_coordinator.dart';
import 'tournament/tournament_query_coordinator.dart';
import 'tournament/tournament_registration_coordinator.dart';
import 'tournament/tournament_roster_coordinator.dart';
import 'tournament/tournament_stats_coordinator.dart';

export 'tournament/tournament_bracket_engine.dart';
export 'tournament/tournament_fixture_coordinator.dart';
export 'tournament/tournament_lifecycle_coordinator.dart';
export 'tournament/tournament_match_coordinator.dart';
export 'tournament/tournament_payload_builder.dart';
export 'tournament/tournament_query_coordinator.dart';
export 'tournament/tournament_registration_coordinator.dart';
export 'tournament/tournament_roster_coordinator.dart';
export 'tournament/tournament_stats_coordinator.dart';

/// Central repository facade for tournament championships, matches, brackets, and standings.
class TournamentRepository {
  final SupabaseClient? _client;
  final TournamentQueryCoordinator? _queryCoordinator;
  final TournamentLifecycleCoordinator? _lifecycleCoordinator;
  final TournamentStatsCoordinator? _statsCoordinator;
  final TournamentRosterCoordinator? _rosterCoordinator;
  final TournamentRegistrationCoordinator? _registrationCoordinator;
  final TournamentMatchCoordinator? _matchCoordinator;
  final TournamentFixtureCoordinator? _fixtureCoordinator;

  TournamentRepository({
    SupabaseClient? client,
    TournamentQueryCoordinator? queryCoordinator,
    TournamentLifecycleCoordinator? lifecycleCoordinator,
    TournamentStatsCoordinator? statsCoordinator,
    TournamentRosterCoordinator? rosterCoordinator,
    TournamentRegistrationCoordinator? registrationCoordinator,
    TournamentMatchCoordinator? matchCoordinator,
    TournamentFixtureCoordinator? fixtureCoordinator,
  })  : _client = client,
        _queryCoordinator = queryCoordinator,
        _lifecycleCoordinator = lifecycleCoordinator,
        _statsCoordinator = statsCoordinator,
        _rosterCoordinator = rosterCoordinator,
        _registrationCoordinator = registrationCoordinator,
        _matchCoordinator = matchCoordinator,
        _fixtureCoordinator = fixtureCoordinator;

  TournamentQueryCoordinator get queryCoord =>
      _queryCoordinator ?? TournamentQueryCoordinator(client: _client);

  TournamentLifecycleCoordinator get lifecycleCoord =>
      _lifecycleCoordinator ?? TournamentLifecycleCoordinator(client: _client);

  TournamentStatsCoordinator get statsCoord =>
      _statsCoordinator ?? TournamentStatsCoordinator(client: _client);

  TournamentRosterCoordinator get rosterCoord =>
      _rosterCoordinator ?? TournamentRosterCoordinator(client: _client);

  TournamentRegistrationCoordinator get registrationCoord =>
      _registrationCoordinator ??
      TournamentRegistrationCoordinator(
        client: _client,
        rosterCoordinator: rosterCoord,
      );

  TournamentMatchCoordinator get matchCoord =>
      _matchCoordinator ??
      TournamentMatchCoordinator(
        client: _client,
        onChampionCrowned: crownChampionCelebration,
      );

  TournamentFixtureCoordinator get fixtureCoord =>
      _fixtureCoordinator ??
      TournamentFixtureCoordinator(
        client: _client,
        getTeamsByIds: getTeamsByIds,
        statsCoordinator: statsCoord,
      );

  // ==================== QUERY & STREAMING ====================

  Stream<List<Championship>> getChampionshipsStream({
    String? governorate,
    String? sportType,
    bool isOwner = false,
    String? ownerId,
  }) =>
      queryCoord.getChampionshipsStream(
        governorate: governorate,
        sportType: sportType,
        isOwner: isOwner,
        ownerId: ownerId,
      );

  Future<List<Championship>> getChampionships({
    String? governorate,
    String? sportType,
    bool isOwner = false,
    String? ownerId,
  }) =>
      queryCoord.getChampionships(
        governorate: governorate,
        sportType: sportType,
        isOwner: isOwner,
        ownerId: ownerId,
      );

  Future<Championship?> getChampionshipById(String id) =>
      queryCoord.getChampionshipById(id);

  Future<List<Team>> getTeamsByIds(List<String> ids) =>
      queryCoord.getTeamsByIds(ids);

  Future<List<TournamentMatch>> getTournamentMatchesDirectly(
    String championshipId,
  ) =>
      queryCoord.getTournamentMatchesDirectly(championshipId);

  Stream<List<TournamentMatch>> getTournamentMatches(String championshipId) =>
      queryCoord.getTournamentMatches(championshipId);

  Stream<Championship?> getSingleChampionshipStream(String championshipId) =>
      queryCoord.getSingleChampionshipStream(championshipId);

  Stream<List<Map<String, dynamic>>> streamChampionshipRaw(
    String championshipId,
  ) =>
      queryCoord.streamChampionshipRaw(championshipId);

  // ==================== LIFECYCLE & MANAGEMENT ====================

  Future<String?> createChampionship(Map<String, dynamic> data) =>
      lifecycleCoord.createChampionship(data);

  Future<bool> activateChampionship(String championshipId) =>
      lifecycleCoord.activateChampionship(championshipId);

  Future<bool> updateChampionship(String id, Map<String, dynamic> data) =>
      lifecycleCoord.updateChampionship(id, data);

  Future<void> updateChampionshipStatus(
    String championshipId,
    String status,
  ) =>
      lifecycleCoord.updateChampionshipStatus(championshipId, status);

  Future<void> crownChampion(
    String championshipId,
    String winningTeamId,
    String winningTeamName,
  ) =>
      lifecycleCoord.crownChampion(
        championshipId,
        winningTeamId,
        winningTeamName,
      );

  Future<void> crownChampionCelebration(String teamId) =>
      lifecycleCoord.sendCelebrationNotifications(teamId);

  Future<bool> deleteChampionship(String championshipId) =>
      lifecycleCoord.deleteChampionship(championshipId);

  Future<Map<String, dynamic>> markChampionshipPrizeDelivered(
    String championshipId, {
    String? notes,
  }) =>
      lifecycleCoord.markChampionshipPrizeDelivered(
        championshipId,
        notes: notes,
      );

  // ==================== REGISTRATION & ORDERS ====================

  Future<bool> joinChampionship(
    String championshipId,
    String teamId, {
    List<String> selectedPlayerIds = const [],
    List<String> offlineGuestNames = const [],
    bool skipMemberCheck = false,
    bool isPaid = false,
    double? totalPaidAmount,
  }) =>
      registrationCoord.joinChampionship(
        championshipId,
        teamId,
        selectedPlayerIds: selectedPlayerIds,
        offlineGuestNames: offlineGuestNames,
        skipMemberCheck: skipMemberCheck,
        isPaid: isPaid,
        totalPaidAmount: totalPaidAmount,
      );

  Future<Map<String, dynamic>?> createTournamentOrder({
    required String championshipId,
    required String teamId,
    required double amount,
    List<String> playerIds = const [],
    List<String> guestNames = const [],
  }) =>
      registrationCoord.createTournamentOrder(
        championshipId: championshipId,
        teamId: teamId,
        amount: amount,
        playerIds: playerIds,
        guestNames: guestNames,
      );

  Future<bool> confirmTournamentOrder({
    required String orderReference,
    required String paymobTransactionId,
  }) =>
      registrationCoord.confirmTournamentOrder(
        orderReference: orderReference,
        paymobTransactionId: paymobTransactionId,
      );

  Future<bool> leaveChampionship(String championshipId, String teamId) =>
      registrationCoord.leaveChampionship(championshipId, teamId);

  Future<bool> removeTournamentTeam(String championshipId, String teamId) =>
      registrationCoord.removeTournamentTeam(championshipId, teamId);

  Future<void> toggleTeamPayment({
    required String championshipId,
    required String teamId,
    required bool isPaid,
  }) =>
      registrationCoord.toggleTeamPayment(
        championshipId: championshipId,
        teamId: teamId,
        isPaid: isPaid,
      );

  Future<bool> is1v1OrderPaid(String orderReference) =>
      registrationCoord.is1v1OrderPaid(orderReference);

  // ==================== ROSTERS ====================

  Future<Map<String, List<String>>> fetchRosters(
    String championshipId,
    String homeTeamId,
    String awayTeamId,
  ) =>
      rosterCoord.fetchRosters(championshipId, homeTeamId, awayTeamId);

  Future<Map<String, dynamic>> getSingleTeamRoster(
    String championshipId,
    String teamId,
  ) =>
      rosterCoord.getSingleTeamRoster(championshipId, teamId);

  Future<bool> updateSingleTeamRoster({
    required String championshipId,
    required String teamId,
    required List<String> playerIds,
    required List<String> guestNames,
  }) =>
      rosterCoord.updateSingleTeamRoster(
        championshipId: championshipId,
        teamId: teamId,
        playerIds: playerIds,
        guestNames: guestNames,
      );

  Future<void> insertChampionshipRoster({
    required String championshipId,
    required String teamId,
    required List<String> guestNames,
    List<String> playerIds = const [],
  }) =>
      rosterCoord.insertChampionshipRoster(
        championshipId: championshipId,
        teamId: teamId,
        guestNames: guestNames,
        playerIds: playerIds,
      );

  Future<List<String>> checkDuplicatePlayersInChampionship({
    required String championshipId,
    required String currentTeamId,
    required List<String> playerIds,
    required List<String> guestNames,
  }) =>
      rosterCoord.checkDuplicatePlayersInChampionship(
        championshipId: championshipId,
        currentTeamId: currentTeamId,
        playerIds: playerIds,
        guestNames: guestNames,
      );

  // ==================== MATCHES & SCHEDULING ====================

  Future<void> updateTournamentMatchScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
    int? homePenalties,
    int? awayPenalties,
    String? winnerId,
    String? winnerName,
    List<GoalItem> goalDetails = const [],
  }) =>
      matchCoord.updateTournamentMatchScore(
        matchId: matchId,
        homeScore: homeScore,
        awayScore: awayScore,
        homePenalties: homePenalties,
        awayPenalties: awayPenalties,
        winnerId: winnerId,
        winnerName: winnerName,
        goalDetails: goalDetails,
      );

  Future<void> updateMatchScheduledTime({
    required String matchId,
    required DateTime scheduledTime,
  }) =>
      matchCoord.updateMatchScheduledTime(
        matchId: matchId,
        scheduledTime: scheduledTime,
      );

  Future<bool> autoScheduleRoundMatches({
    required String championshipId,
    required int roundIndex,
    required List<TournamentMatch> matches,
    required DateTime startDate,
    required TimeOfDay startTime,
    required int daysCount,
    required int matchDurationMinutes,
  }) =>
      matchCoord.autoScheduleRoundMatches(
        championshipId: championshipId,
        roundIndex: roundIndex,
        matches: matches,
        startDate: startDate,
        startTime: startTime,
        daysCount: daysCount,
        matchDurationMinutes: matchDurationMinutes,
      );

  Future<bool> clearRoundMatchSchedules({
    required String championshipId,
    required int roundIndex,
    required List<TournamentMatch> matches,
  }) =>
      matchCoord.clearRoundMatchSchedules(
        championshipId: championshipId,
        roundIndex: roundIndex,
        matches: matches,
      );

  Future<String?> checkMatchScheduleConflict({
    required String championshipId,
    required String matchId,
    required String? homeTeamId,
    required String? awayTeamId,
    required DateTime scheduledTime,
    int matchDurationMinutes = 45,
  }) =>
      matchCoord.checkMatchScheduleConflict(
        championshipId: championshipId,
        matchId: matchId,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        scheduledTime: scheduledTime,
        matchDurationMinutes: matchDurationMinutes,
      );

  // ==================== STATISTICS ====================

  Future<List<Map<String, dynamic>>> getTopScorersForChampionship(
    String championshipId,
  ) =>
      statsCoord.getTopScorersForChampionship(championshipId);

  Future<List<Map<String, dynamic>>> getCleanSheetsForChampionship(
    String championshipId,
  ) =>
      statsCoord.getCleanSheetsForChampionship(championshipId);

  Future<List<Map<String, dynamic>>> getChampionshipStandings(
    String championshipId, {
    String? groupName,
  }) =>
      statsCoord.getChampionshipStandings(
        championshipId,
        groupName: groupName,
      );

  // ==================== FIXTURES ====================

  Future<void> generateFixtures(String championshipId) =>
      fixtureCoord.generateFixtures(championshipId);

  Future<void> generateLeagueFixtures(String championshipId) =>
      fixtureCoord.generateLeagueFixtures(championshipId);

  Future<void> generateGroupsFixtures(String championshipId) =>
      fixtureCoord.generateGroupsFixtures(championshipId);

  Future<void> advanceGroupsToKnockout(String championshipId) =>
      fixtureCoord.advanceGroupsToKnockout(championshipId);
}
