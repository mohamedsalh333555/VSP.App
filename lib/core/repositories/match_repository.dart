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
 .from('booking_public_feed')
 .stream(primaryKey: ['id'])
 .timeout(
 const Duration(seconds: 10),
 onTimeout: (sink) => sink.add([]),
 )
 .handleError((e) {
 VSPLogger.w('Handled realtime error in getMatches: $e');
 });
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


 /// Safe public-match detail read. The bookings table remains private; this RPC
 /// returns only fields required by the public match room.
 Future<Booking?> getPublicMatchDetails(String bookingId) async {
   try {
     final response = await _supabase.rpc(
       'get_public_match_details',
       params: {'p_booking_id': bookingId},
     );
     if (response is Map) {
       return Booking.fromFirestore(
         Map<String, dynamic>.from(response),
         bookingId,
       );
     }
     return null;
   } on PostgrestException catch (e) {
     VSPLogger.w('Public match details RPC failed: ${e.message}');
     return null;
   } catch (e, stack) {
     VSPLogger.e('Error loading public match details', e, stack);
     return null;
   }
 }

 Future<Booking?> getPrivateCollectiveMatchDetails(String bookingId) async {
   try {
     final response = await _supabase.rpc(
       'get_private_collective_match_details',
       params: {'p_booking_id': bookingId},
     );
     if (response is Map) {
       return Booking.fromFirestore(Map<String, dynamic>.from(response), bookingId);
     }
     return null;
   } on PostgrestException catch (e) {
     VSPLogger.w('Private collective details RPC failed: ' + e.message);
     return null;
   } catch (e, stack) {
     VSPLogger.e('Error loading private collective details', e, stack);
     return null;
   }
 }

 Future<Map<String, dynamic>?> getPrivateCollectiveInviteDetails(String inviteToken) async {
   try {
     final response = await _supabase.rpc(
       'get_private_collective_invite_details',
       params: {'p_invite_token': inviteToken},
     );
     return response is Map ? Map<String, dynamic>.from(response) : null;
   } on PostgrestException catch (e) {
     VSPLogger.w('Private collective invite RPC failed: ' + e.message);
     return null;
   } catch (e, stack) {
     VSPLogger.e('Error loading private collective invite', e, stack);
     return null;
   }
 }

 Future<Map<String, dynamic>?> getPrivateCollectiveInviteByCode(String code) async {
   try {
     final response = await _supabase.rpc(
       'get_private_collective_invite_by_code',
       params: {'p_invite_code': code.trim().toUpperCase()},
     );
     return response is Map ? Map<String, dynamic>.from(response) : null;
   } on PostgrestException catch (e) {
     VSPLogger.w('Collective invite code RPC failed: ' + e.message);
     return null;
   } catch (e, stack) {
     VSPLogger.e('Error loading collective invite by code', e, stack);
     return null;
   }
 }

 Future<Map<String, dynamic>?> getCollectiveInviteCredentials(String bookingId) async {
   try {
     final response = await _supabase.rpc(
       'get_collective_invite_credentials',
       params: {'p_booking_id': bookingId},
     );
     return response is Map ? Map<String, dynamic>.from(response) : null;
   } on PostgrestException catch (e) {
     VSPLogger.w('Collective invite credentials RPC failed: ' + e.message);
     return null;
   } catch (e, stack) {
     VSPLogger.e('Error loading collective invite credentials', e, stack);
     return null;
   }
 }

 Future<bool> joinPrivateCollectiveMatch({required String inviteToken, required String userId}) async {
   try {
     final response = await _supabase.rpc(
       'join_private_collective_match_atomic',
       params: {'p_invite_token': inviteToken, 'p_user_id': userId},
     );
     if (response is Map && response['success'] == false) {
       throw Exception(response['message'] ?? response['error'] ?? 'تعذر الانضمام للمباراة.');
     }
     return response is Map ? response['success'] != false : true;
   } on PostgrestException catch (e) {
     final message = e.message.toLowerCase();
     if (message.contains('collective_governorate_mismatch')) throw Exception('لا يمكنك الانضمام لهذه التجميعية لأن الملعب في محافظة مختلفة عن محافظتك.');
     if (message.contains('governorate_not_verified')) throw Exception('يجب تحديد محافظتك أولاً للانضمام إلى هذه التجميعية.');
     if (message.contains('match_awaiting_host_payment')) throw Exception('المنشئ لم يؤكد الدفع بعد. حاول مرة أخرى بعد تأكيد الحجز.');
     if (message.contains('match_is_full')) throw Exception('اكتملت التجميعية بالفعل.');
     if (message.contains('already_joined')) return true;
     if (message.contains('time_conflict')) throw Exception('لديك حجز آخر يتعارض مع موعد هذه المباراة.');
     rethrow;
   }
 }

 Future<bool> updateCollectiveManualPlayers({required String bookingId, required int manualPlayerCount}) async {
   final userId = _supabase.auth.currentUser?.id;
   if (userId == null) return false;
   try {
     final response = await _supabase.rpc(
       'update_collective_manual_players_atomic',
       params: {'p_booking_id': bookingId, 'p_user_id': userId, 'p_manual_player_count': manualPlayerCount},
     );
     if (response is Map && response['success'] == false) return false;
     return true;
   } catch (e, stack) {
     VSPLogger.e('Error updating collective manual players', e, stack);
     return false;
   }
 }
 /// Realtime public match stream. The public feed drives updates while the
 /// RPC supplies the protected participant identifiers needed by the room.
 Stream<Booking?> streamPublicMatchDetails(String bookingId) async* {
   final initial = await getPublicMatchDetails(bookingId);
   if (initial != null) {
     yield initial;
   }

   yield* _supabase
       .from('booking_public_feed')
       .stream(primaryKey: ['id'])
       .eq('id', bookingId)
       .map((rows) => rows.isEmpty ? null : rows.first)
       .asyncMap((_) => getPublicMatchDetails(bookingId))
       .handleError((error) {
         VSPLogger.w('Handled public match details realtime error: \$error');
       });
 }

 // --- PUBLIC MATCHES (Modern Supabase Integration) ---

 Stream<List<Booking>> getPublicMatches() async* {
 final now = DateTime.now();
 final cutoffIso = now.subtract(const Duration(hours: 2)).toUtc().toIso8601String();

 // 1. جلب أولي سريع ومفلتر على مستوى قاعدة البيانات (Server-side Filtered REST Query)
 try {
 final response = await _supabase
 .from('booking_public_feed')
 .select()
 .eq('is_private', false)
 .inFilter('status', ['confirmed'])
 .gte('end_time', cutoffIso)
 .order('start_time', ascending: true)
 .limit(50);

 final initialList = (response as List)
 .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
 .where((b) {
 final totalCapacity = b.totalFieldCapacity;
 final hasSpace = b.currentPlayers < totalCapacity;
 return b.endTime.isAfter(now) && hasSpace;
 })
 .toList();

 yield initialList;
 } catch (e, stack) {
 VSPLogger.e('Error fetching initial public matches via REST', e, stack);
 }

 // 2. التسمع اللحظي للتحديثات (Realtime Stream)
 yield* _supabase
 .from('booking_public_feed')
 .stream(primaryKey: ['id'])
 .eq('is_private', false)
 .order('start_time', ascending: true)
 .timeout(
 const Duration(seconds: 10),
 onTimeout: (sink) => VSPLogger.w('Public matches realtime stream timed out'),
 )
 .map<List<Booking>>((list) {
 final currentNow = DateTime.now();
 final currentCutoff = currentNow.subtract(const Duration(hours: 2));

 return list
 .map((data) => Booking.fromFirestore(data, data['id'].toString()))
 .where((b) {
 final isNotExpired = b.endTime.isAfter(currentCutoff);
 final isConfirmed = b.status == BookingStatus.confirmed;
 final isFuture = b.endTime.isAfter(currentNow);
 
 final totalCapacity = b.totalFieldCapacity;
 final hasSpace = b.currentPlayers < totalCapacity;
 
 return isNotExpired && isConfirmed && isFuture && hasSpace;
 })
 .toList();
 })
 .handleError((error) {
 VSPLogger.w('Handled realtime error in getPublicMatches: $error');
 });
 }

 Future<bool> joinPublicMatch(String bookingId, String userId) async {
 try {
 // Public Matchmaking: Atomic RPC Database Lock & Time-Conflict check
 final joinResult = await _supabase.rpc('request_join_public_match', params: {
 'p_booking_id': bookingId,
 'p_user_id': userId,
 });

 // Only non-sensitive match data is read from the public feed.
 final finalDoc = await _supabase
 .from('booking_public_feed')
 .select('stadium_name, current_players, total_field_capacity')
 .eq('id', bookingId)
 .single();

 final hostId = joinResult is Map ? (joinResult['host_user_id']?.toString() ?? '') : '';
 final stadiumName = finalDoc['stadium_name'] ?? 'Match';

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

 // Participant identifiers are intentionally not exposed through the public feed.
 // The host receives the join notification; full-match fan-out is handled by later event work.

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
 .from('booking_public_feed')
 .select('id, stadium_name, host_name')
 .eq('id', bookingId)
 .maybeSingle();

 final hostId = doc?['created_by_user_id'] ?? doc?['owner_id'] ?? '';
 final stadiumName = doc?['stadium_name'] ?? 'Match';

 // PostgreSQL Atomic Leave Match RPC (Prevents Race Conditions)
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
 title: 'Player Left Match ',
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
 } on PostgrestException catch (e) {
 VSPLogger.e('Postgrest error leaving public match', e);
 if (e.message.contains('HOST_CANNOT_LEAVE')) {
 throw 'لا يمكن لمضيف المباراة المغادرة، يمكنك إلغاء الحجز بدلاً من ذلك.';
 } else if (e.message.contains('LEAVE_BLOCKED')) {
 throw 'لا يمكن مغادرة مباراة منتهية أو ملغاة.';
 }
 throw e.message;
 } catch (e) {
 VSPLogger.e('Error leaving public match', e);
 rethrow;
 }
 }

 Future<bool> removeParticipantFromPublicMatch(String bookingId, String userId) async {
 try {
 final doc = await _supabase
 .from('booking_public_feed')
 .select('id, stadium_name')
 .eq('id', bookingId)
 .maybeSingle();

 final stadiumName = doc?['stadium_name'] ?? 'Match';

 // PostgreSQL Atomic RPC
 await _supabase.rpc('remove_public_match_participant_atomic', params: {
 'p_booking_id': bookingId,
 'p_user_id': userId,
 });

 await _notificationRepo.sendNotification(
 userId,
 AppNotification(
 id: '',
 title: 'Match Participation Cancelled ',
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

 Future<bool> leavePrivateCollectiveMatch(String bookingId, String userId) async {
 try {
   await _supabase.rpc('leave_private_collective_match_atomic', params: {
     'p_booking_id': bookingId,
     'p_user_id': userId,
   });
   return true;
 } on PostgrestException catch (e) {
   final message = e.message.toLowerCase();
   if (message.contains('host_cannot_leave')) {
     throw Exception('لا يمكن لمنشئ الحجز المغادرة؛ استخدم إلغاء الحجز.');
   }
   if (message.contains('leave_blocked')) {
     throw Exception('لا يمكن مغادرة هذه التجميعية الآن.');
   }
   rethrow;
 }
 }

 Future<bool> removePrivateCollectiveParticipant(String bookingId, String participantId) async {
   try {
     await _supabase.rpc('remove_private_collective_participant_atomic', params: {
       'p_booking_id': bookingId,
       'p_participant_id': participantId,
     });
     return true;
   } catch (e, stack) {
     VSPLogger.e('Error removing private collective participant', e, stack);
     rethrow;
   }
 }

 Future<bool> updatePublicMatchHostSpots(String bookingId, int newHostSpotsCount) async {

 try {
 final uid = _supabase.auth.currentUser?.id ?? '';
 // PostgreSQL Atomic RPC
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
 
 // الفلترة تتم الآن على مستوى الخادم أولاً قبل التقسيم الصفحي
 final response = await _supabase
 .from('booking_public_feed')
 .select()
 .eq('is_private', false)
 .inFilter('status', ['confirmed'])
 .gte('end_time', cutoffIso)
 .order('start_time', ascending: true)
 .range(offset, offset + limit - 1);

 final items = (response as List)
 .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
 .where((b) {
 final isFuture = b.endTime.isAfter(now);
 final hasSpace = b.currentPlayers < b.totalFieldCapacity;
  return isFuture && hasSpace;
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
