import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';
import '../services/notification_handler.dart';
import 'notification_repository.dart';
import 'user_repository.dart';

class MatchRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _notificationRepo;

  MatchRepository({NotificationRepository? notificationRepo})
      : _notificationRepo = notificationRepo ?? NotificationRepository();

  // Get all matches (Live stream)
  Stream<List<Map<String, dynamic>>> getMatches() {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map((list) => list);
  }

  // Legacy Match Join (Compatibility wrapper)
  Future<bool> joinMatch(String matchId, String userId) async {
    return joinPublicMatch(matchId, userId);
  }

  // Legacy Match Leave (Compatibility wrapper)
  Future<bool> leaveMatch(String matchId, String userId) async {
    return leavePublicMatch(matchId, userId);
  }

  Stream<List<Map<String, dynamic>>> getMatchesStream() {
    return getMatches();
  }

  // --- PUBLIC MATCHES (Modern Supabase Integration) ---

  Stream<List<Booking>> getPublicMatches() async* {
    final now = DateTime.now();
    final cutoffIso = now.subtract(const Duration(hours: 2)).toUtc().toIso8601String();

    // 1. ⚡ جلب أولي سريع ومفلتر على مستوى قاعدة البيانات (Server-side Filtered REST Query)
    try {
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('is_private', false)
          .inFilter('status', ['confirmed', 'upcoming'])
          .gte('end_time', cutoffIso)
          .order('start_time', ascending: true)
          .limit(50);

      final initialList = (response as List)
          .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .where((b) {
            final totalCapacity = b.totalFieldCapacity;
            final hasSpace = b.currentPlayers < totalCapacity;
            final uid = _supabase.auth.currentUser?.id;
            final isParticipant = uid != null && b.joinedUserIds.contains(uid);
            return b.endTime.isAfter(now) && (hasSpace || isParticipant);
          })
          .toList();

      yield initialList;
    } catch (e, stack) {
      VSPLogger.e('Error fetching initial public matches via REST', e, stack);
    }

    // 2. 📡 التسمع اللحظي للتحديثات (Realtime Stream)
    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('is_private', false)
        .order('start_time', ascending: true)
        .map<List<Booking>>((list) {
          final currentNow = DateTime.now();
          final currentCutoff = currentNow.subtract(const Duration(hours: 2));

          return list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                final isNotExpired = b.endTime.isAfter(currentCutoff);
                final isConfirmed = b.status == BookingStatus.confirmed || 
                                   b.status == BookingStatus.upcoming;
                final isFuture = b.endTime.isAfter(currentNow);
                
                final totalCapacity = b.totalFieldCapacity;
                final hasSpace = b.currentPlayers < totalCapacity;
                
                final uid = _supabase.auth.currentUser?.id;
                final isParticipant = uid != null && b.joinedUserIds.contains(uid);
                return isNotExpired && isConfirmed && isFuture && (hasSpace || isParticipant);
              })
              .toList();
        });
  }

  Future<bool> joinPublicMatch(String bookingId, String userId) async {
    try {
      // 🛡️ Public Matchmaking: Atomic RPC Database Lock & Time-Conflict check
      await _supabase.rpc('request_join_public_match', params: {
        'p_booking_id': bookingId,
        'p_user_id': userId,
      });

      // Retrieve final details for notifications
      final finalDoc = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();

      final hostId = finalDoc['created_by_user_id'] ?? finalDoc['owner_id'] ?? '';
      final stadiumName = finalDoc['stadium_name'] ?? 'Match';
      final finalCurrent = finalDoc['current_players'] ?? 0;
      final ppt = finalDoc['players_per_team'] ?? finalDoc['playersPerTeam'];
      final totalCapacity = finalDoc['total_field_capacity'] ?? finalDoc['totalFieldCapacity'] ?? ((ppt != null) ? ppt * 2 : (finalDoc['max_players'] != null ? finalDoc['max_players'] * 2 : 10));
      final participantIds = List<String>.from(
          (finalDoc['joined_user_ids'] as List?)?.map((e) => e.toString()) ?? []
      );

      String joiningUserName = 'A player';
      try {
        final user = await UserRepository().getUserData(userId);
        if (user != null) {
          joiningUserName = user['name'] ?? 'A player';
        }
      } catch (_) {}

      try {
        if (hostId.isNotEmpty && hostId != userId) {
          await NotificationHandler.notifyPlayerJoinedMatch(
            hostId: hostId,
            playerName: joiningUserName,
            stadiumName: stadiumName,
            bookingId: bookingId,
          );
        }
      } catch (fcmError) {
        VSPLogger.w('FCM notifyPlayerJoinedMatch failed: $fcmError');
      }

      try {
        if (finalCurrent >= totalCapacity) {
          await NotificationHandler.notifyMatchIsFull(
            playerIds: participantIds,
            stadiumName: stadiumName,
            bookingId: bookingId,
          );
        }
      } catch (fcmError) {
        VSPLogger.w('FCM notifyMatchIsFull failed: $fcmError');
      }

      AnalyticsService.logMatchJoined(bookingId, 'public');
      return true;
    } on PostgrestException catch (e) {
      final msg = (e.message + (e.details?.toString() ?? '')).toLowerCase();
      if (msg.contains('time_conflict')) {
        throw 'time_conflict';
      } else if (msg.contains('match_is_full')) {
        throw 'match_is_full';
      } else if (msg.contains('already_joined')) {
        throw 'already_joined';
      } else {
        throw e.message;
      }
    } catch (e, stack) {
      VSPLogger.e('Error joining public match', e, stack);
      rethrow;
    }
  }

  Future<bool> acceptJoinRequest(String bookingId, String userId) async {
    try {
      await _supabase.rpc('accept_join_request', params: {'p_booking_id': bookingId, 'p_user_id': userId});
      return true;
    } catch (e) { return false; }
  }

  Future<bool> rejectJoinRequest(String bookingId, String userId) async {
    try {
      await _supabase.rpc('reject_join_request', params: {'p_booking_id': bookingId, 'p_user_id': userId});
      return true;
    } catch (e) { return false; }
  }

  Future<bool> leavePublicMatch(String bookingId, String userId) async {
    try {
      final doc = await _supabase
          .from('bookings')
          .select('created_by_user_id, owner_id, stadium_name')
          .eq('id', bookingId)
          .maybeSingle();

      final hostId = doc?['created_by_user_id'] ?? doc?['owner_id'] ?? '';
      final stadiumName = doc?['stadium_name'] ?? 'Match';

      // 🛡️ PostgreSQL Atomic Leave Match RPC (Prevents Race Conditions)
      await _supabase.rpc('leave_public_match_atomic', params: {
        'p_booking_id': bookingId,
        'p_user_id': userId,
      });

      String leavingUserName = 'A player';
      try {
        final user = await UserRepository().getUserData(userId);
        if (user != null) {
          leavingUserName = user['name'] ?? 'A player';
        }
      } catch (_) {}

      try {
        if (hostId.isNotEmpty && hostId != userId) {
          await _notificationRepo.sendNotification(
            hostId,
            AppNotification(
              id: '',
              title: 'Player Left Match ⚠️',
              body: '$leavingUserName left your match at $stadiumName.',
              type: 'info',
              createdAt: DateTime.now(),
              bookingId: bookingId,
            ),
          );
        }
      } catch (fcmError) {
        VSPLogger.w('FCM sendNotification failed on player leaving: $fcmError');
      }
      return true;
    } catch (e) {
      VSPLogger.e('Error leaving public match', e);
      return false;
    }
  }

  Future<bool> removeParticipantFromPublicMatch(String bookingId, String userId) async {
    try {
      final doc = await _supabase
          .from('bookings')
          .select('stadium_name')
          .eq('id', bookingId)
          .maybeSingle();

      final stadiumName = doc?['stadium_name'] ?? 'Match';

      // 🛡️ PostgreSQL Atomic RPC
      await _supabase.rpc('leave_public_match_atomic', params: {
        'p_booking_id': bookingId,
        'p_user_id': userId,
      });

      await _notificationRepo.sendNotification(
        userId,
        AppNotification(
          id: '',
          title: 'Match Participation Cancelled ❕',
          body: 'The host has removed you from the match at $stadiumName.',
          type: 'info',
          createdAt: DateTime.now(),
          bookingId: bookingId,
        ),
      );

      return true;
    } catch (e) {
      VSPLogger.e('Error removing participant from public match', e);
      return false;
    }
  }

  Future<bool> updatePublicMatchHostSpots(String bookingId, int newHostSpotsCount) async {
    try {
      final uid = _supabase.auth.currentUser?.id ?? '';
      // 🛡️ PostgreSQL Atomic RPC
      await _supabase.rpc('update_host_spots_atomic', params: {
        'p_booking_id': bookingId,
        'p_user_id': uid,
        'p_new_host_spots': newHostSpotsCount,
      });

      return true;
    } catch (e) {
      VSPLogger.e('Error updating host spots', e);
      return false;
    }
  }

  Future<Map<String, dynamic>> getPublicMatchesPaginated({
    int limit = 10,
    dynamic startAfter,
  }) async {
    try {
      final now = DateTime.now();
      final cutoffIso = now.subtract(const Duration(hours: 2)).toUtc().toIso8601String();
      int offset = 0;
      if (startAfter is int) {
        offset = startAfter;
      }
      
      // ⚡ الفلترة تتم الآن على مستوى الخادم أولاً قبل التقسيم الصفحي
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('is_private', false)
          .inFilter('status', ['confirmed', 'upcoming'])
          .gte('end_time', cutoffIso)
          .order('start_time', ascending: true)
          .range(offset, offset + limit - 1);

      final items = (response as List)
          .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .where((b) {
            final isFuture = b.endTime.isAfter(now);
            final hasSpace = b.currentPlayers < b.totalFieldCapacity;
            final uid = _supabase.auth.currentUser?.id;
            final isParticipant = uid != null && b.joinedUserIds.contains(uid);
            return isFuture && (hasSpace || isParticipant);
          }).toList();

      return {
        'items': items,
        'lastDoc': offset + items.length,
      };
    } catch (e, stack) {
      VSPLogger.e('Error fetching paginated matches', e, stack);
      return {'items': [], 'lastDoc': null};
    }
  }
}
