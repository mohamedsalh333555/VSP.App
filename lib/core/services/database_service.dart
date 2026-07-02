import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore;
  
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

  DatabaseService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance {
    user = UserRepository();
    team = TeamRepository();
    report = ReportRepository(firestore: _firestore);
    notification = NotificationRepository(firestore: _firestore);
    league = LeagueRepository(firestore: _firestore);
    match = MatchRepository(firestore: _firestore);
    stadium = StadiumRepository();
    booking = SupabaseBookingRepository(); // Note: Internal implementation
    search = SearchRepository();
    owner = OwnerRepository(firestore: _firestore);
    tournament = TournamentRepository();
  }

  // --- Redirection methods for backward compatibility ---
  // Note: These will be removed once all callers are migrated.

  @deprecated
  Future<dynamic> getUserByPhone(String p) => user.getUserByPhone(p);
  
  @deprecated
  Future<Team?> getUserTeam(String uid) => team.getUserTeam(uid);

  @deprecated
  Stream<List<dynamic>> getPublicMatches() => match.getPublicMatches();

  @deprecated
  Stream<List<dynamic>> getPromotionsStream() => stadium.getPromotionsStream();

  @deprecated
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

  @deprecated
  Future<Map<String, List<dynamic>>> globalUnifiedSearch(String q) => search.globalUnifiedSearch(q);

  @deprecated
  Future<bool> joinPublicMatch(String bookingId, String userId) => match.joinPublicMatch(bookingId, userId);

  @deprecated
  Future<bool> leavePublicMatch(String bookingId, String userId) => match.leavePublicMatch(bookingId, userId);

  @deprecated
  Future<Team?> getTeam(String id) => team.getTeam(id);

  @deprecated
  Future<void> sendNotification(String uid, AppNotification n) => notification.sendNotification(uid, n);

  @deprecated
  Stream<List<Team>> getTeams({String? governorate}) => team.getTeams(governorate: governorate);

  @deprecated
  Stream<int> getUnreadNotificationCount(String userId) => notification.getUnreadNotificationCount(userId);

  @deprecated
  Future<void> updateMatchResult(String b, String h, String a, MatchOutcome o) => team.updateMatchResult(b, h, a, o);

  @deprecated
  Future<bool> joinMatch(String mid, String uid) => match.joinMatch(mid, uid);

  @deprecated
  Future<bool> leaveMatch(String mid, String uid) => match.leaveMatch(mid, uid);

  @deprecated
  Future<void> generateFixtures(String cid) => tournament.generateFixtures(cid);

  @deprecated
  Future<void> updateTournamentMatchScore({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String winnerId,
    required String winnerName,
  }) => tournament.updateTournamentMatchScore(
    matchId: matchId, 
    homeScore: homeScore, 
    awayScore: awayScore, 
    winnerId: winnerId, 
    winnerName: winnerName
  );

  @deprecated
  Stream<List<Map<String, dynamic>>> getReportsStream() => report.getReportsStream();

  @deprecated
  Future<void> updateUserModerationStatus(String userId, {required bool isBlocked, String? warningMessage}) => user.updateUserModerationStatus(userId, isBlocked: isBlocked, warningMessage: warningMessage);

  @deprecated
  Future<double> calculateOwnerRevenue(String id) => owner.calculateOwnerRevenue(id);

  @deprecated
  Future<int> calculateBookedHours(String id) => owner.calculateBookedHours(id);

  @deprecated
  Stream<List<Stadium>> getOwnerStadiums(String id) => owner.getOwnerStadiums(id);

  @deprecated
  Future<String?> createTeam(Map<String, dynamic> data) => team.createTeam(data);

  @deprecated
  Future<List<Team>> searchOpponentTeams(String q) => team.searchOpponentTeams(q);

  @deprecated
  Future<List<Team>> getPreviousOpponents(String tid) => team.getPreviousOpponents(tid);

  @deprecated
  Future<Map<String, int>> getHeadToHeadStats(String t1, String t2) => team.getHeadToHeadStats(t1, t2);

  @deprecated
  Future<Team?> getTeamByCaptainPhone(String p) => team.getTeamByCaptainPhone(p);

  @deprecated
  Stream<List<VSP1v1Player>> get1v1Standings() => league.get1v1Standings();

  @deprecated
  Future<List<UserModel>> getUsersByIds(List<String> ids) => user.getUsersByIds(ids);

  @deprecated
  Future<void> addMemberToTeam(String teamId, String userId, String imageUrl) => team.addMemberToTeam(teamId, userId, imageUrl);

  @deprecated
  Future<void> removeMemberFromTeam(String teamId, String userId, String imageUrl) => team.removeMemberFromTeam(teamId, userId, imageUrl);

  @deprecated
  Future<bool> updateTeam(String teamId, Map<String, dynamic> data) => team.updateTeam(teamId, data);

  @deprecated
  Future<bool> deleteTeam(String teamId) => team.deleteTeam(teamId);
}
