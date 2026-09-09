import '../../../data/models.dart';
import '../../repositories/match_repository.dart';
import 'booking_categorization_service.dart';

/// Coordinates public match fetching, joining, and leaving for [BookingProvider].
class BookingMatchCoordinator {
  final MatchRepository? _matchRepositoryInstance;

  BookingMatchCoordinator({MatchRepository? matchRepository})
      : _matchRepositoryInstance = matchRepository;

  MatchRepository get _matchRepository =>
      _matchRepositoryInstance ?? MatchRepository();

  /// Fetches public matches stream snapshot.
  Future<List<Booking>> fetchPublicMatches() async {
    final stream = _matchRepository.getPublicMatches();
    final matches = await stream.first;
    return List<Booking>.from(matches);
  }

  /// Attempts to join a public match and returns success status or formatted error.
  Future<({bool success, String? error})> joinPublicMatch({
    required String bookingId,
    required String userId,
  }) async {
    try {
      final success = await _matchRepository.joinPublicMatch(bookingId, userId);
      return (success: success, error: null);
    } catch (e) {
      return (success: false, error: BookingCategorizationService.formatPublicMatchError(e));
    }
  }

  /// Leaves a joined public match and returns success status or error.
  Future<({bool success, String? error})> leavePublicMatch({
    required String bookingId,
    required String userId,
  }) async {
    try {
      final success = await _matchRepository.leavePublicMatch(bookingId, userId);
      return (success: success, error: null);
    } catch (e) {
      return (success: false, error: 'Error leaving match: $e');
    }
  }
}
