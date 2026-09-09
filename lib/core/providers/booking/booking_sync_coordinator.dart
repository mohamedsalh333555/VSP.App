import 'dart:async';
import '../../../data/models.dart';
import '../../repositories/booking_repository.dart';
import '../../services/logger_service.dart';
import 'booking_categorization_service.dart';

/// Coordinates REST and Realtime WebSocket synchronizations for owner and player bookings.
class BookingSyncCoordinator {
  final BookingRepository _repository;
  StreamSubscription? _subscription;

  BookingSyncCoordinator(this._repository);

  /// Cancels active synchronization subscription.
  void cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Syncs player bookings via instant direct REST fetch and persistent Realtime Stream.
  void syncUserBookings({
    required String userId,
    required void Function(List<Booking> userBookings, CategorizedUserBookings categorized) onData,
    required void Function(String error) onError,
  }) {
    // 1. Direct REST fetch for immediate UI population
    try {
      final repo = _repository;
      if (repo is SupabaseBookingRepository) {
        repo.getUserBookingsDirectly(userId).then((directList) {
          if (directList.isNotEmpty) {
            final categorized = BookingCategorizationService.categorizeUserBookings(
              bookings: directList,
              now: DateTime.now(),
            );
            onData(directList, categorized);
          }
        });
      }
    } catch (e, stack) {
      VSPLogger.e('Error loading direct user bookings in BookingSyncCoordinator', e, stack);
    }

    // 2. Realtime Stream subscription
    _subscription?.cancel();
    _subscription = _repository.getUserBookings(userId).listen(
      (bookings) {
        final categorized = BookingCategorizationService.categorizeUserBookings(
          bookings: bookings,
          now: DateTime.now(),
        );
        onData(bookings, categorized);
      },
      onError: (e) {
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
