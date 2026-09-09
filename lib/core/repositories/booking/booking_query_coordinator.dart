import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';
import 'booking_domain_rules.dart';

/// Handles read queries, direct REST fetches, and real-time streams for bookings.
class BookingQueryCoordinator {
  final SupabaseClient? _client;

  BookingQueryCoordinator({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Stream of bookings created by user with real-time updates.
  Stream<List<Booking>> getUserBookings(String userId) async* {
    final direct = await getUserBookingsDirectly(userId);
    if (direct.isNotEmpty) yield direct;

    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('created_by_user_id', userId)
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .toList();
          bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
          return bookings;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getUserBookingsDirectly(userId);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getUserBookings: $error');
        });
  }

  /// Direct REST query fetching user bookings.
  Future<List<Booking>> getUserBookingsDirectly(String userId) async {
    try {
      final bool isValidId = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(userId);
      if (!isValidId) return [];

      final response = await _supabase
          .from('bookings')
          .select()
          .or('user_id.eq.$userId,created_by_user_id.eq.$userId,joined_user_ids.cs.{"$userId"}')
          .order('start_time', ascending: false)
          .limit(100);

      final bookings = (response as List)
          .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .where((b) =>
              b.userId.trim().toLowerCase() == userId.trim().toLowerCase() ||
              b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(userId.trim().toLowerCase()))
          .toList();
      VSPLogger.i('getUserBookingsDirectly returned ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      VSPLogger.e('Error in getUserBookingsDirectly: $e');
      return [];
    }
  }

  /// Direct REST query fetching owner stadium bookings.
  Future<List<Booking>> fetchOwnerBookingsDirectly(String ownerId, {List<String>? stadiumIds}) async {
    try {
      final response = await (stadiumIds != null && stadiumIds.isNotEmpty
          ? _supabase.from('bookings').select().inFilter('stadium_id', stadiumIds).order('start_time', ascending: false).limit(100)
          : _supabase.from('bookings').select().eq('owner_id', ownerId).order('start_time', ascending: false).limit(100));
      return (response as List)
          .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .toList();
    } catch (e) {
      VSPLogger.e('Error fetching owner bookings directly: $e');
      return [];
    }
  }

  /// Real-time stream of stadium owner bookings.
  Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds}) async* {
    final lowerStadiumIds = stadiumIds?.map((id) => id.toLowerCase()).toList();

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
                if (lowerStadiumIds != null && lowerStadiumIds.isNotEmpty) {
                  return lowerStadiumIds.contains(b.stadiumId.toLowerCase());
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
            final refreshed = await fetchOwnerBookingsDirectly(ownerId, stadiumIds: stadiumIds);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getOwnerBookings: $error');
        });
  }

  /// Fetches a single booking by ID.
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .maybeSingle();
      if (response != null) {
        return Booking.fromFirestore(response, response['id'].toString());
      }
      return null;
    } catch (e) {
      debugPrint('Error getting booking: $e');
      return null;
    }
  }

  /// Real-time stream of upcoming confirmed bookings for a player.
  Stream<List<Booking>> getUpcomingBookings(String userId) {
    final now = DateTime.now();
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('created_by_user_id', userId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) => b.status == BookingStatus.confirmed && b.startTime.isAfter(now))
              .toList();
          bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
          return bookings;
        })
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getUpcomingBookings: $error');
        });
  }

  /// Real-time stream of completed bookings history.
  Stream<List<Booking>> getBookingHistory(String userId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('created_by_user_id', userId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) => b.status == BookingStatus.completed)
              .toList();
          bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
          return bookings;
        })
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getBookingHistory: $error');
        });
  }

  /// Direct REST query fetching bookings for a pitch on a specific calendar day.
  Future<List<Booking>> fetchStadiumBookingsDirectly(String stadiumId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 2));

      final response = await _supabase
          .from('bookings')
          .select()
          .eq('stadium_id', stadiumId)
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String());

      return (response as List)
          .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .where((b) {
            if (b.status == BookingStatus.cancelled) return false;
            if (b.status == BookingStatus.pending) {
              final isExpired = BookingDomainRules.isPendingBookingExpired(b.createdAt, DateTime.now());
              if (isExpired) return false;
            }
            return true;
          })
          .toList();
    } catch (e) {
      VSPLogger.w('fetchStadiumBookingsDirectly notice: $e');
      return [];
    }
  }

  /// Real-time stream of stadium bookings for booking sheet schedule.
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) async* {
    final direct = await fetchStadiumBookingsDirectly(stadiumId, date);
    if (direct.isNotEmpty) yield direct;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 2));

    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('stadium_id', stadiumId)
        .map((list) {
          return list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                if (b.status == BookingStatus.cancelled) return false;
                if (b.status == BookingStatus.pending) {
                  final isExpired = BookingDomainRules.isPendingBookingExpired(b.createdAt, DateTime.now());
                  if (isExpired) return false;
                }
                return b.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                    b.startTime.isBefore(endOfDay);
              })
              .toList();
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await fetchStadiumBookingsDirectly(stadiumId, date);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getBookingsForStadium: $error');
        });
  }

  /// Fetches unpaid confirmed bookings for player.
  Future<List<Booking>> getUnpaidBookingsForUser(String userId) async {
    try {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('created_by_user_id', userId)
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
