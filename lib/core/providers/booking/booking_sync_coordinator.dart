import 'dart:async';
import '../../../data/models.dart';
import '../../repositories/booking_repository.dart';
import '../../services/logger_service.dart';
import 'booking_categorization_service.dart';

/// Coordinates REST and Realtime WebSocket synchronizations for owner and player bookings.
class BookingSyncCoordinator {
  final BookingRepository _repository;
  StreamSubscription? _subscription;

  /// Tracks the last trusted full server list for player bookings.
  /// Used to detect disappearances caused by partial Realtime events.
  List<Booking> _lastKnownUserBookings = [];

  BookingSyncCoordinator(this._repository);

  /// Cancels active synchronization subscription.
  void cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Returns true when [userId] is the creator, owner, or participant of [booking].
  static bool _isUserBooking(Booking booking, String lowerUserId) {
    return booking.createdByUserId.trim().toLowerCase() == lowerUserId ||
        booking.userId.trim().toLowerCase() == lowerUserId ||
        booking.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId);
  }

  /// Merges an incoming Realtime list with the last known trusted server list.
  ///
  /// Rule: a booking that belongs to [userId] is NEVER dropped from local state
  /// purely because the Realtime event doesn't include it (partial/reconnect events).
  /// Only a confirmed Server value (`cancelled`/`expired`) actually removes a booking.
  List<Booking> _mergeWithLastKnown({
    required List<Booking> incoming,
    required String userId,
  }) {
    final lowerUserId = userId.trim().toLowerCase();
    final result = Map<String, Booking>.fromEntries(
      incoming.where((b) => _isUserBooking(b, lowerUserId)).map((b) => MapEntry(b.id, b)),
    );

    for (final known in _lastKnownUserBookings) {
      if (result.containsKey(known.id)) continue; // already in incoming — updated version wins
      if (!_isUserBooking(known, lowerUserId)) continue; // not our booking
      // Keep cancelled/completed bookings for history — they shouldn't silently vanish either.
      // Only truly irrelevant bookings (e.g. not belonging to this user) are dropped.
      // Booking remains in local state; the next full Server refresh will confirm final state.
      result[known.id] = known;
    }

    final merged = result.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return merged;
  }

  /// Syncs player bookings via instant direct REST fetch and persistent Realtime Stream.
  ///
  /// SSOT Rule: Realtime = transport, not source of truth.
  /// Incoming stream results are MERGED with last known state, never blindly replacing it.
  /// On error/timeout, existing bookings are preserved; the UI shows an error state.
  void syncUserBookings({
    required String userId,
    required void Function(List<Booking> userBookings, CategorizedUserBookings categorized) onData,
    required void Function(String error) onError,
  }) {
    // 1. Direct REST fetch (trusted) — populates UI immediately and sets baseline.
    try {
      _repository.getUserBookingsDirectly(userId).then((directList) {
        if (directList.isNotEmpty) {
          // Full server refresh → update last-known baseline.
          _lastKnownUserBookings = directList;
          final categorized = BookingCategorizationService.categorizeUserBookings(
            bookings: directList,
            now: DateTime.now(),
          );
          onData(directList, categorized);
        }
      }).catchError((e) {
        // Direct fetch failed — do NOT clear existing state.
        VSPLogger.w('Direct user bookings fetch failed (keeping existing state): $e');
      });
    } catch (e, stack) {
      VSPLogger.e('Error loading direct user bookings in BookingSyncCoordinator', e, stack);
    }

    // 2. Realtime Stream — transport only, results merged with last-known state.
    _subscription?.cancel();
    _subscription = _repository.getUserBookings(userId).listen(
      (incoming) {
        // Merge incoming with last known — never replace if incoming is partial.
        final merged = _mergeWithLastKnown(incoming: incoming, userId: userId);
        // Update baseline only when incoming actually contains this user's bookings
        // (i.e. it's a meaningful non-empty result, not an empty reconnect event).
        final lowerUserId = userId.trim().toLowerCase();
        final incomingHasUserBookings = incoming.any((b) => _isUserBooking(b, lowerUserId));
        if (incomingHasUserBookings || incoming.isNotEmpty) {
          _lastKnownUserBookings = merged;
        }
        final categorized = BookingCategorizationService.categorizeUserBookings(
          bookings: merged,
          now: DateTime.now(),
        );
        onData(merged, categorized);
      },
      onError: (e) {
        // Transport error — preserve existing state, report error to UI.
        VSPLogger.w('Realtime stream error in syncUserBookings (keeping existing state): $e');
        // Re-emit last known so UI doesn't go blank.
        if (_lastKnownUserBookings.isNotEmpty) {
          final categorized = BookingCategorizationService.categorizeUserBookings(
            bookings: _lastKnownUserBookings,
            now: DateTime.now(),
          );
          onData(_lastKnownUserBookings, categorized);
        }
        onError('Failed to load bookings: $e');
      },
    );
  }

  /// Syncs owner bookings via instant direct REST fetch and persistent Realtime Stream.
  Future<void> syncOwnerBookings({
    required String ownerId,
    List<String>? stadiumIds,
    required List<Booking> Function() getCurrentBookings,
    required Set<String> cancellingIds,
    required void Function(List<Booking> mergedBookings, CategorizedOwnerBookings categorized) onData,
    required void Function(String error) onError,
  }) async {
    // 1. Direct REST fetch for immediate UI population
    try {
      final repo = _repository;
      if (repo is SupabaseBookingRepository) {
        final directBookings = await repo.fetchOwnerBookingsDirectly(ownerId);
        if (directBookings.isNotEmpty) {
          final categorized = BookingCategorizationService.categorizeOwnerBookings(
            bookings: directBookings,
            now: DateTime.now(),
          );
          onData(directBookings, categorized);
        }
      }
    } catch (e, stack) {
      VSPLogger.e('Error loading direct owner bookings in BookingSyncCoordinator', e, stack);
    }

    // 2. Realtime Stream subscription
    _subscription?.cancel();
    _subscription = _repository.getOwnerBookings(ownerId, stadiumIds: stadiumIds).listen(
      (bookings) {
        final merged = BookingCategorizationService.mergeLocalManualBookings(
          incomingBookings: bookings,
          currentBookings: getCurrentBookings(),
          cancellingIds: cancellingIds,
        );
        final categorized = BookingCategorizationService.categorizeOwnerBookings(
          bookings: merged,
          now: DateTime.now(),
        );
        onData(merged, categorized);
      },
      onError: (e) {
        onError('Failed to load bookings: $e');
      },
    );
  }

  /// Disposes coordinator resources.
  void dispose() {
    cancelSubscription();
  }
}
