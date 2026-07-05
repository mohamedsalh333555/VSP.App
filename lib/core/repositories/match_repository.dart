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

  MatchRepository({dynamic firestore, NotificationRepository? notificationRepo})
      : _notificationRepo = notificationRepo ?? NotificationRepository(firestore: firestore);

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

  Stream<List<Booking>> getPublicMatches() {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map<List<Booking>>((list) {
          final now = DateTime.now();
          final matches = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                // Client-side filtering
                final isConfirmed = b.status == BookingStatus.confirmed || 
                                   b.status == BookingStatus.upcoming;
                final isFuture = b.startTime.isAfter(now);
                
                final totalCapacity = b.totalFieldCapacity;
                final hasSpace = b.currentPlayers < totalCapacity;
                
                return !b.isPrivate && isConfirmed && isFuture && hasSpace;
              })
              .toList();
              
          matches.sort((a, b) => a.startTime.compareTo(b.startTime));
          return matches;
        });
  }

  Future<bool> joinPublicMatch(String bookingId, String userId) async {
    try {
      String hostId = '';
      String stadiumName = '';
      String joiningUserName = 'A player';

      // ── Enforce Time conflict block ──
      final matchDoc = await _supabase
          .from('bookings')
          .select('start_time, end_time, status')
          .eq('id', bookingId)
          .maybeSingle();
      if (matchDoc == null) throw 'Match not found';
      
      final DateTime matchStart = DateTime.parse(matchDoc['start_time'].toString()).toUtc();
      final DateTime matchEnd = DateTime.parse(matchDoc['end_time'].toString()).toUtc();

      final userBookings = await _supabase
          .from('bookings')
          .select('id, start_time, end_time, status, joined_user_ids, created_by_user_id')
          .eq('status', BookingStatus.confirmed.name);

      final List bookingsList = userBookings as List;
      for (final doc in bookingsList) {
        final String otherId = doc['id'].toString();
        if (otherId == bookingId) continue;

        final String createdBy = doc['created_by_user_id'] ?? '';
        final List joinedIds = doc['joined_user_ids'] is List ? doc['joined_user_ids'] : [];

        final isUserParticipant = (createdBy == userId) || joinedIds.contains(userId);
        if (!isUserParticipant) continue;

        final DateTime otherStart = DateTime.parse(doc['start_time'].toString()).toUtc();
        final DateTime otherEnd = DateTime.parse(doc['end_time'].toString()).toUtc();

        if (matchStart.isBefore(otherEnd) && matchEnd.isAfter(otherStart)) {
          throw 'time_conflict';
        }
      }

      // 1. Try safe transactional join via Supabase RPC
      bool rpcSuccess = false;
      try {
        await _supabase.rpc('join_public_match', params: {
          'p_booking_id': bookingId,
          'p_user_id': userId,
        });
        rpcSuccess = true;
      } catch (rpcError) {
        VSPLogger.w('RPC failed: $rpcError');
        rpcSuccess = false;
      }

      if (!rpcSuccess) {
        // هنا نقوم برمي استثناء فوري بدلاً من السماح للعميل بتحديث البيانات يدوياً
        throw Exception("عذراً، تداخلت عمليتك مع مستخدم آخر واكتمل عدد مقاعد المباراة بالفعل! ⚠️");
      }

      // 3. Retrieve final details for notifications
      final finalDoc = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();

      hostId = finalDoc['owner_id'] ?? finalDoc['created_by_user_id'] ?? '';
      stadiumName = finalDoc['stadium_name'] ?? 'Match';
      final finalCurrent = finalDoc['current_players'] ?? 0;
      final ppt = finalDoc['players_per_team'] ?? finalDoc['playersPerTeam'];
      final totalCapacity = finalDoc['total_field_capacity'] ?? finalDoc['totalFieldCapacity'] ?? ((ppt != null) ? ppt * 2 : (finalDoc['max_players'] != null ? finalDoc['max_players'] * 2 : 10));
      final participantIds = List<String>.from(
          (finalDoc['joined_user_ids'] as List?)?.map((e) => e.toString()) ?? []
      );

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
    } catch (e, stack) {
      VSPLogger.e('Error joining public match', e, stack);
      rethrow;
    }
  }

  Future<bool> leavePublicMatch(String bookingId, String userId) async {
    try {
      final doc = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .maybeSingle();
      if (doc == null) throw 'Match not found';

      final hostId = doc['owner_id'] ?? doc['created_by_user_id'] ?? '';
      final stadiumName = doc['stadium_name'] ?? 'Match';
      
      final joinedList = doc['joined_user_ids'];
      final joined = joinedList != null 
          ? List<String>.from((joinedList as List).map((e) => e.toString()))
          : <String>[];

      if (!joined.contains(userId)) throw 'Not a participant';

      joined.remove(userId);
      final current = doc['current_players'] ?? 0;

      final response = await _supabase.from('bookings').update({
        'current_players': current > 0 ? current - 1 : 0,
        'joined_user_ids': joined,
      }).eq('id', bookingId).eq('current_players', current).select();

      if ((response as List).isEmpty) {
        throw 'Race condition detected: current_players updated during transaction. Please try again.';
      }

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
          .select()
          .eq('id', bookingId)
          .maybeSingle();
      if (doc == null) throw 'Match not found';

      final stadiumName = doc['stadium_name'] ?? 'Match';
      final joinedList = doc['joined_user_ids'];
      final joined = joinedList != null 
          ? List<String>.from((joinedList as List).map((e) => e.toString()))
          : <String>[];

      if (!joined.contains(userId)) throw 'User is not a participant';

      joined.remove(userId);
      final current = doc['current_players'] ?? 0;

      await _supabase.from('bookings').update({
        'current_players': current > 0 ? current - 1 : 0,
        'joined_user_ids': joined,
      }).eq('id', bookingId);

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
      final doc = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .maybeSingle();
      if (doc == null) throw 'Match not found';

      final ppt = doc['players_per_team'] ?? doc['playersPerTeam'];
      final totalFieldCapacity = doc['total_field_capacity'] ?? doc['totalFieldCapacity'] ?? ((ppt != null) ? ppt * 2 : (doc['max_players'] != null ? doc['max_players'] * 2 : 10));
      final joinedList = doc['joined_user_ids'];
      final joined = joinedList != null 
          ? List<String>.from((joinedList as List).map((e) => e.toString()))
          : <String>[];

      final newCurrentPlayers = joined.length + newHostSpotsCount;
      final current = doc['current_players'] ?? 0;

      if (newCurrentPlayers > totalFieldCapacity) {
        throw 'Exceeds stadium capacity';
      }

      final response = await _supabase.from('bookings').update({
        'current_players': newCurrentPlayers,
      }).eq('id', bookingId).eq('current_players', current).select();

      if ((response as List).isEmpty) {
        throw 'Race condition detected: current_players updated during transaction. Please try again.';
      }

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
      int offset = 0;
      if (startAfter is int) {
        offset = startAfter;
      }
      
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('is_private', false)
          .range(offset, offset + limit - 1);

      final items = (response as List)
          .map((data) => Booking.fromFirestore(data, data['id'].toString()))
          .where((b) {
            final isConfirmed = b.status == BookingStatus.confirmed || 
                               b.status == BookingStatus.upcoming;
            final isFuture = b.startTime.isAfter(now);
            final hasSpace = b.currentPlayers < b.totalFieldCapacity;
            final isRightType = b.bookingType == BookingType.team || b.bookingType == BookingType.personal;
            return isConfirmed && isFuture && hasSpace && isRightType;
          }).toList();

      items.sort((a, b) => a.startTime.compareTo(b.startTime));

      return {
        'items': items,
        'lastDoc': offset + limit,
      };
    } catch (e) {
      VSPLogger.e('Error fetching paginated matches', e);
      return {'items': [], 'lastDoc': null};
    }
  }
}
