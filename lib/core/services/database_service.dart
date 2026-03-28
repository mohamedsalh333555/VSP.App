import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/user_repository.dart';
import '../repositories/team_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/league_repository.dart';
import '../repositories/match_repository.dart';
import '../repositories/stadium_repository.dart';
import '../repositories/booking_repository.dart';
import '../repositories/search_repository.dart';
import '../repositories/owner_repository.dart';

/// LEGACY FACADE: This class is being phased out in favor of individual repositories.
/// New code should use [UserRepository], [TeamRepository], etc., directly.
class DatabaseService {
  final FirebaseFirestore _firestore;
  
  // Repository Singletons/Instances
  late final UserRepository user;
  late final TeamRepository team;
  late final NotificationRepository notification;
  late final LeagueRepository league;
  late final MatchRepository match;
  late final StadiumRepository stadium;
  late final BookingRepository booking;
  late final SearchRepository search;
  late final OwnerRepository owner;

  DatabaseService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance {
    user = UserRepository(firestore: _firestore);
    team = TeamRepository(firestore: _firestore);
    notification = NotificationRepository(firestore: _firestore);
    league = LeagueRepository(firestore: _firestore);
    match = MatchRepository(firestore: _firestore);
    stadium = StadiumRepository(firestore: _firestore);
    booking = FirestoreBookingRepository(); // Note: Internal implementation
    search = SearchRepository(firestore: _firestore);
    owner = OwnerRepository(firestore: _firestore);
  }

  // --- Redirection methods for backward compatibility ---
  // Note: These will be removed once all callers are migrated.

  @deprecated
  Future<dynamic> getUserByPhone(String p) => user.getUserByPhone(p);
  
  @deprecated
  Future<dynamic> getUserTeam(String uid) => team.getUserTeam(uid);

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
  }) => user.reportEntity(
    reporterId: reporterId, 
    targetId: targetId, 
    targetType: targetType, 
    reason: reason
  );

  @deprecated
  Future<Map<String, List<dynamic>>> globalUnifiedSearch(String q) => search.globalUnifiedSearch(q);

  // Add more redirections if critical files still depend on DatabaseService()
}
