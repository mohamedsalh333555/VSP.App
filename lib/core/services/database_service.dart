import '../../data/models.dart';
import '../repositories/user_repository.dart';
import '../repositories/team_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/league_repository.dart';
import '../repositories/match_repository.dart';
import '../repositories/stadium_repository.dart';
import '../repositories/booking_repository.dart';
import '../repositories/search_repository.dart';
import '../repositories/owner_repository.dart';
import '../repositories/tournament_repository.dart';
import '../models/user_model.dart'; // Added for UserModel support

/// LEGACY FACADE: This class is being phased out in favor of individual repositories.
/// New code should use [UserRepository], [TeamRepository], etc., directly.
class DatabaseService {
  // Repository Singletons/Instances
  late final UserRepository user;
  late final TeamRepository team;
  late final ReportRepository report;
  late final NotificationRepository notification;
  late final LeagueRepository league;
  late final MatchRepository match;
  late final StadiumRepository stadium;
  late final BookingRepository booking;
  late final SearchRepository search;
  late final OwnerRepository owner;
  late final TournamentRepository tournament;

  DatabaseService({dynamic firestore}) {
    user = UserRepository();
    team = TeamRepository();
    report = ReportRepository();
    notification = NotificationRepository();
    league = LeagueRepository();
    match = MatchRepository();
    stadium = StadiumRepository();
    booking = SupabaseBookingRepository(); // Note: Internal implementation
    search = SearchRepository();
    owner = OwnerRepository();
    tournament = TournamentRepository();
  }

  // --- Redirection methods for backward compatibility ---
  // Note: These will be removed once all callers are migrated.

  @Deprecated('Use UserRepository.getUserByPhone() directly')
  Future<dynamic> getUserByPhone(String p) => user.getUserByPhone(p);
  
  @Deprecated('Use TeamRepository.getUserTeam() directly')
  Future<Team?> getUserTeam(String uid) => team.getUserTeam(uid);

  @Deprecated('Use MatchRepository.getPublicMatches() directly')
  Stream<List<dynamic>> getPublicMatches() => match.getPublicMatches();

  @Deprecated('Use StadiumRepository.getPromotionsStream() directly')
  Stream<List<dynamic>> getPromotionsStream() => stadium.getPromotionsStream();

  @Deprecated('Use ReportRepository.reportEntity() directly')
  Future<bool> reportEntity({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
  }) => report.reportEntity(
    reporterId: reporterId, 
    targetId: targetId, 
    targetType: targetType, 
    reason: reason
  );

  @Deprecated('Use SearchRepository.globalUnifiedSearch() directly')
  Future<Map<String, List<dynamic>>> globalUnifiedSearch(String q) => search.globalUnifiedSearch(q);

  @Deprecated('Use MatchRepository.joinPublicMatch() directly')
  Future<bool> joinPublicMatch(String bookingId, String userId) => match.joinPublicMatch(bookingId, userId);

  @Deprecated('Use MatchRepository.leavePublicMatch() directly')
  Future<bool> leavePublicMatch(String bookingId, String userId) => match.leavePublicMatch(bookingId, userId);

  @Deprecated('Use TeamRepository.getTeam() directly')
  Future<Team?> getTeam(String id) => team.getTeam(id);

  @Deprecated('Use NotificationRepository.sendNotification() directly')
  Future<void> sendNotification(String uid, AppNotification n) => notification.sendNotification(uid, n);

  @Deprecated('Use TeamRepository.getTeams() directly')
  Stream<List<Team>> getTeams({String? governorate}) => team.getTeams(governorate: governorate);

  @Deprecated('Use NotificationRepository.getUnreadNotificationCount() directly')
  Stream<int> getUnreadNotificationCount(String userId) => notification.getUnreadNotificationCount(userId);

  @Deprecated('Use TeamRepository.updateMatchResult() directly')
  Future<void> updateMatchResult(String b, String h, String a, MatchOutcome o) => team.updateMatchResult(b, h, a, o);

  @Deprecated('Use MatchRepository.joinMatch() directly')
  Future<bool> joinMatch(String mid, String uid) => match.joinMatch(mid, uid);

  @Deprecated('Use MatchRepository.leaveMatch() directly')
  Future<bool> leaveMatch(String mid, String uid) => match.leaveMatch(mid, uid);

  @Deprecated('Use TournamentRepository.generateFixtures() directly')
  Future<void> generateFixtures(String cid) => tournament.generateFixtures(cid);

  @Deprecated('Use TournamentRepository.updateTournamentMatchScore() directly')
  Future<void> updateTournamentMatchScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
    String? winnerId,
    String? winnerName,
  }) => tournament.updateTournamentMatchScore(
    matchId: matchId, 
    homeScore: homeScore, 
    awayScore: awayScore, 
    winnerId: winnerId, 
    winnerName: winnerName
  );

  @Deprecated('Use ReportRepository.getReportsStream() directly')
  Stream<List<Map<String, dynamic>>> getReportsStream() => report.getReportsStream();

  @Deprecated('Use UserRepository.updateUserModerationStatus() directly')
  Future<void> updateUserModerationStatus(String userId, {required bool isBlocked, String? warningMessage}) => user.updateUserModerationStatus(userId, isBlocked: isBlocked, warningMessage: warningMessage);

  @Deprecated('Use OwnerRepository.calculateOwnerRevenue() directly')
  Future<double> calculateOwnerRevenue(String id) => owner.calculateOwnerRevenue(id);

  @Deprecated('Use OwnerRepository.calculateBookedHours() directly')
  Future<int> calculateBookedHours(String id) => owner.calculateBookedHours(id);

  @Deprecated('Use OwnerRepository.getOwnerStadiums() directly')
  Stream<List<Stadium>> getOwnerStadiums(String id) => owner.getOwnerStadiums(id);

  @Deprecated('Use TeamRepository.createTeam() directly')
  Future<String?> createTeam(Map<String, dynamic> data) => team.createTeam(data);

  @Deprecated('Use TeamRepository.searchOpponentTeams() directly')
  Future<List<Team>> searchOpponentTeams(String q) => team.searchOpponentTeams(q);

  @Deprecated('Use TeamRepository.getPreviousOpponents() directly')
  Future<List<Team>> getPreviousOpponents(String tid) => team.getPreviousOpponents(tid);

  @Deprecated('Use TeamRepository.getHeadToHeadStats() directly')
  Future<Map<String, int>> getHeadToHeadStats(String t1, String t2) => team.getHeadToHeadStats(t1, t2);

  @Deprecated('Use TeamRepository.getTeamByCaptainPhone() directly')
  Future<Team?> getTeamByCaptainPhone(String p) => team.getTeamByCaptainPhone(p);

  @Deprecated('Use LeagueRepository.get1v1Standings() directly')
  Stream<List<VSP1v1Player>> get1v1Standings() => league.get1v1Standings();

  @Deprecated('Use UserRepository.getUsersByIds() directly')
  Future<List<UserModel>> getUsersByIds(List<String> ids) => user.getUsersByIds(ids);

  @Deprecated('Use TeamRepository.addMemberToTeam() directly')
  Future<void> addMemberToTeam(String teamId, String userId, String imageUrl) => team.addMemberToTeam(teamId, userId, imageUrl);

  @Deprecated('Use TeamRepository.removeMemberFromTeam() directly')
  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) => team.removeMemberFromTeam(teamId, userId, imageUrl);

  @Deprecated('Use TeamRepository.updateTeam() directly')
  Future<bool> updateTeam(String teamId, Map<String, dynamic> data) => team.updateTeam(teamId, data);

  @Deprecated('Use TeamRepository.deleteTeam() directly')
  Future<bool> deleteTeam(String teamId) => team.deleteTeam(teamId);

  @Deprecated('Use TeamRepository directly')
  Future<bool> has1v1Champion(String teamId) => team.has1v1Champion(teamId);
}
