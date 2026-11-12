import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';


/// Handles read queries, direct REST fetches, and real-time streams for bookings.
class BookingQueryCoordinator {
  final SupabaseClient? _client;

  BookingQueryCoordinator({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Stream of bookings created by user with real-time updates.
  Stream<List<Booking>> getUserBookings(String userId) async* {
    if (userId.trim().isEmpty) {
      yield <Booking>[];
      return;
    }
    final direct = await getUserBookingsDirectly(userId);
    if (direct.isNotEmpty) yield direct;

    final lowerUserId = userId.trim().toLowerCase();

    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) =>
                  b.createdByUserId.trim().toLowerCase() == lowerUserId ||
                  b.userId.trim().toLowerCase() == lowerUserId ||
                  b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId))
              .toList();
          bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
          return bookings;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getUserBookingsDirectlyStrict(userId);
            sink.add(refreshed);
          },
        );
  }

  /// Direct REST query fetching user bookings. This compatibility method
  /// preserves the historical empty-list fallback for non-critical callers.
  Future<List<Booking>> getUserBookingsDirectly(String userId) async {
    try {
      return await getUserBookingsDirectlyStrict(userId);
    } catch (e) {
      VSPLogger.e('Error in getUserBookingsDirectly: $e');
      return [];
    }
  }

  /// Strict direct fetch for synchronization paths that must distinguish an
  /// authoritative empty result from a failed request.
  Future<List<Booking>> getUserBookingsDirectlyStrict(String userId) async {
    if (userId.trim().isEmpty) return [];
    final response = await _supabase
        .from('bookings')
        .select()
        .or('user_id.eq.$userId,created_by_user_id.eq.$userId,joined_user_ids.cs.{"$userId"}')
        .order('start_time', ascending: false)
        .limit(100);
    final lowerUserId = userId.trim().toLowerCase();
    final bookings = (response as List)
        .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
        .where((b) =>
            b.createdByUserId.trim().toLowerCase() == lowerUserId ||
            b.userId.trim().toLowerCase() == lowerUserId ||
            b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId))
        .toList();
    VSPLogger.i('getUserBookingsDirectlyStrict returned ${bookings.length} bookings');
    return bookings;
  }

  /// Direct REST query fetching owner stadium bookings.
  Future<List<Booking>> fetchOwnerBookingsDirectly(String ownerId, {List<String>? stadiumIds}) async {
    try {
      return await fetchOwnerBookingsDirectlyStrict(ownerId, stadiumIds: stadiumIds);
    } catch (e) {
      VSPLogger.e('Error fetching owner bookings directly: $e');
      return [];
    }
  }

  /// Strict owner fetch used by the booking sync coordinator.
  Future<List<Booking>> fetchOwnerBookingsDirectlyStrict(String ownerId, {List<String>? stadiumIds}) async {
    final normalizedOwnerId = ownerId.trim().toLowerCase();
    if (normalizedOwnerId.isEmpty) return <Booking>[];

    // Stadium IDs are an optional narrowing filter, never an alternative to
    // owner identity. A caller-supplied stadium list must not broaden reads.
    var query = _supabase.from('bookings').select().eq('owner_id', ownerId);
    if (stadiumIds != null && stadiumIds.isNotEmpty) {
      query = query.inFilter('stadium_id', stadiumIds);
    }
    final response = await query.order('start_time', ascending: false).limit(100);
    final allowedStadiumIds = stadiumIds?.map((id) => id.trim().toLowerCase()).toSet();
    return (response as List)
        .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
        .where((booking) =>
            normalizedOwnerId.isNotEmpty &&
            booking.ownerId.trim().toLowerCase() == normalizedOwnerId &&
            (allowedStadiumIds == null ||
                allowedStadiumIds.isEmpty ||
                allowedStadiumIds.contains(booking.stadiumId.trim().toLowerCase())))
        .toList();
  }
  /// Real-time stream of stadium owner bookings.
  Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds}) async* {
    final lowerStadiumIds = stadiumIds?.map((id) => id.trim().toLowerCase()).toList();
    final normalizedOwnerId = ownerId.trim().toLowerCase();
    if (normalizedOwnerId.isEmpty) {
      yield <Booking>[];
      return;
    }

    final direct = await fetchOwnerBookingsDirectly(ownerId, stadiumIds: stadiumIds);
    if (direct.isNotEmpty) yield direct;

    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .limit(100)
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                if (b.ownerId.trim().toLowerCase() != normalizedOwnerId) {
                  return false;
                }
                if (lowerStadiumIds != null && lowerStadiumIds.isNotEmpty) {
                  return lowerStadiumIds.contains(b.stadiumId.trim().toLowerCase());
                }
                return true;
              })
              .toList();
          bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
          return bookings;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await fetchOwnerBookingsDirectlyStrict(ownerId, stadiumIds: stadiumIds);
            sink.add(refreshed);
          },
        );
  }

  /// Fetches a single booking by ID.
  Future<Booking?> getBookingByIdStrict(String bookingId) async {
    final response = await _supabase
        .from('bookings')
        .select()
        .eq('id', bookingId)
        .maybeSingle();
    if (response == null) return null;
    return Booking.fromFirestore(response, response['id'].toString());
  }

  Future<Booking?> getBookingById(String bookingId) async {
    try {
      return await getBookingByIdStrict(bookingId);
    } catch (e) {
      debugPrint('Error getting booking: $e');
      return null;
    }
  }

  /// Real-time stream of upcoming confirmed bookings for a player.
  Stream<List<Booking>> getUpcomingBookings(String userId) async* {
    if (userId.trim().isEmpty) {
      yield <Booking>[];
      return;
    }
    final lowerUserId = userId.trim().toLowerCase();
    final direct = await getUserBookingsDirectly(userId);
    if (direct.isNotEmpty) {
      final now = DateTime.now();
      yield direct.where((b) {
        final isParticipant = b.createdByUserId.trim().toLowerCase() == lowerUserId ||
            b.userId.trim().toLowerCase() == lowerUserId ||
            b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId);
        return isParticipant && b.status == BookingStatus.confirmed && b.startTime.isAfter(now);
      }).toList();
    }

    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map((list) {
          final now = DateTime.now();
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                final isParticipant = b.createdByUserId.trim().toLowerCase() == lowerUserId ||
                    b.userId.trim().toLowerCase() == lowerUserId ||
                    b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId);
                return isParticipant && b.status == BookingStatus.confirmed && b.startTime.isAfter(now);
              })
              .toList();
          bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
          return bookings;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getUserBookingsDirectlyStrict(userId);
            final now = DateTime.now();
            final upcoming = refreshed.where((b) {
              final isParticipant = b.createdByUserId.trim().toLowerCase() == lowerUserId ||
                  b.userId.trim().toLowerCase() == lowerUserId ||
                  b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId);
              return isParticipant && b.status == BookingStatus.confirmed && b.startTime.isAfter(now);
            }).toList();
            sink.add(upcoming);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getUpcomingBookings: $error');
        });
  }

  /// Real-time stream of completed bookings history.
  Stream<List<Booking>> getBookingHistory(String userId) async* {
    if (userId.trim().isEmpty) {
      yield <Booking>[];
      return;
    }
    final lowerUserId = userId.trim().toLowerCase();
    final direct = await getUserBookingsDirectly(userId);
    if (direct.isNotEmpty) {
      yield direct.where((b) {
        final isParticipant = b.createdByUserId.trim().toLowerCase() == lowerUserId ||
            b.userId.trim().toLowerCase() == lowerUserId ||
            b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId);
        return isParticipant && b.status == BookingStatus.completed;
      }).toList();
    }

    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                final isParticipant = b.createdByUserId.trim().toLowerCase() == lowerUserId ||
                    b.userId.trim().toLowerCase() == lowerUserId ||
                    b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId);
                return isParticipant && b.status == BookingStatus.completed;
              })
              .toList();
          bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
          return bookings;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getUserBookingsDirectlyStrict(userId);
            final history = refreshed.where((b) {
              final isParticipant = b.createdByUserId.trim().toLowerCase() == lowerUserId ||
                  b.userId.trim().toLowerCase() == lowerUserId ||
                  b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(lowerUserId);
              return isParticipant && b.status == BookingStatus.completed;
            }).toList();
            sink.add(history);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getBookingHistory: $error');
        });
  }

  /// Direct REST query fetching only non-sensitive booking slot data.
  Future<List<Booking>> fetchStadiumBookingsDirectly(String stadiumId, DateTime date) async {
    if (stadiumId.trim().isEmpty) {
      throw ArgumentError.value(stadiumId, 'stadiumId', 'Stadium ID is required');
    }
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      // Two local calendar dates cover bookings crossing midnight, including\n      // days whose UTC offset changes with Egyptian daylight saving time.\n      final endOfDay = DateTime(date.year, date.month, date.day + 2);
      final response = await _supabase.rpc('get_stadium_booking_slots', params: {
        'p_stadium_id': stadiumId,
        'p_start_time': startOfDay.toUtc().toIso8601String(),
        'p_end_time': endOfDay.toUtc().toIso8601String(),
      });
      return (response as List)
          .map((data) => Booking.fromFirestore(
                Map<String, dynamic>.from(data),
                data['id'].toString(),
              ))
          .toList();
    } catch (e) {
      VSPLogger.w('fetchStadiumBookingsDirectly failed');
      rethrow;
    }
  }

  /// Polls the scoped stadium-slot RPC so public users never receive private
  /// booking fields. After any failed refresh, terminate with an error rather
  /// than leave an old successful snapshot selectable indefinitely. The UI
  /// re-subscribes only when the user explicitly retries.
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) async* {
    while (true) {
      try {
        final refreshed = await fetchStadiumBookingsDirectly(stadiumId, date);
        yield refreshed;
      } catch (e, stack) {
        VSPLogger.w('Availability refresh failed; booking selection disabled');
        Error.throwWithStackTrace(e, stack);
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }

  /// Fetches unpaid confirmed bookings for player.
  Future<List<Booking>> getUnpaidBookingsForUser(String userId) async {
    if (userId.trim().isEmpty) return <Booking>[];
    try {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('bookings')
          .select()
          .or('user_id.eq.$userId,created_by_user_id.eq.$userId')
          .eq('is_paid', false)
          .gte('end_time', nowUtcIso)
          .neq('status', 'cancelled')
          .neq('status', 'completed');

      return (response as List)
          .map((doc) => Booking.fromFirestore(doc as Map<String, dynamic>, doc['id'].toString()))
          .toList();
    } catch (e) {
      VSPLogger.e('Error fetching unpaid bookings for user $userId', e);
      return [];
    }
  }

  /// Real-time stream of raw booking rows for status listeners.
  Stream<List<Map<String, dynamic>>> streamBookingStatus(String bookingId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId);
  }

  /// Real-time stream of raw booking for live match room listeners.
  Stream<List<Map<String, dynamic>>> streamBookingRaw(String bookingId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .handleError((e) {
          VSPLogger.w('Handled realtime error in match details: $e');
        });
  }
}
