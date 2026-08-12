import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../services/logger_service.dart';
import '../services/notification_handler.dart';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<ChatMessage>> getChatMessages(String bookingId, {String? currentUserId}) {
    try {
      return _supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('booking_id', bookingId)
          .map((list) {
            try {
              final messages = list
                  .map((data) => ChatMessage.fromJson(data, data['id']?.toString() ?? ''))
                  .where((msg) => currentUserId == null || !msg.deletedForUsers.contains(currentUserId))
                  .toList();
              messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return messages;
            } catch (e) {
              VSPLogger.e('Error mapping chat messages list for booking ', e);
              return <ChatMessage>[];
            }
          })
          .handleError((error) {
            VSPLogger.e('Error in chat messages stream for booking ', error);
            return <ChatMessage>[];
          });
    } catch (e) {
      VSPLogger.e('Failed to initiate getChatMessages stream for booking ', e);
      return Stream.value(<ChatMessage>[]);
    }
  }

  Future<void> sendMessage(String bookingId, ChatMessage message) async {
    try {
      await _supabase.from('chat_messages').insert({
        'booking_id': bookingId,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'text': message.text,
        'created_at': message.timestamp.toUtc().toIso8601String(),
        'is_read': false,
        'is_edited': false,
        'deleted_for_users': [],
      });

      final bookingResponse = await _supabase
          .from('bookings')
          .select('joined_user_ids, unread_counts, owner_id, player_id')
          .eq('id', bookingId)
          .maybeSingle();

      if (bookingResponse != null) {
        final List<dynamic> joinedIds = bookingResponse['joined_user_ids'] ?? [];

        try {
          await _supabase.rpc('increment_chat_unread_count', params: {
            'p_booking_id': bookingId,
            'p_sender_id': message.senderId,
            'p_last_message': message.text,
          });
        } catch (_) {
          final Map<String, dynamic> unreadCounts = Map<String, dynamic>.from(
            bookingResponse['unread_counts'] ?? {}
          );
          for (var uid in joinedIds) {
            final String userId = uid.toString();
            if (userId != message.senderId) {
              final currentCount = (unreadCounts[userId] as int?) ?? 0;
              unreadCounts[userId] = currentCount + 1;
            }
          }
          await _supabase.from('bookings').update({
            'last_message': message.text,
            'last_message_time': DateTime.now().toUtc().toIso8601String(),
            'unread_counts': unreadCounts,
          }).eq('id', bookingId);
        }

        final Set<String> allRecipients = {
          ...joinedIds.map((uid) => uid.toString()),
          if (bookingResponse['owner_id'] != null) bookingResponse['owner_id'].toString(),
          if (bookingResponse['player_id'] != null) bookingResponse['player_id'].toString(),
        };
        final List<String> otherParticipants = allRecipients
            .where((uid) => uid != message.senderId && uid.isNotEmpty)
            .toList();

        if (otherParticipants.isNotEmpty) {
          await NotificationHandler.notifyNewChatMessage(
            recipientIds: otherParticipants,
            senderName: message.senderName,
            messageText: message.text,
            bookingId: bookingId,
          );
        }
      }
    } on PostgrestException catch (e) {
      VSPLogger.e('Postgrest error sending chat message: ', e);
      rethrow;
    } catch (e) {
      VSPLogger.e('Error sending message on Supabase', e);
      rethrow;
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    try {
      await _supabase.from('chat_messages').update({
        'text': newText,
        'is_edited': true,
      }).eq('id', messageId);
    } catch (e) {
      VSPLogger.e('Error editing message ', e);
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String bookingId, String userId) async {
    try {
      try {
        await _supabase.rpc('mark_chat_messages_as_read', params: {
          'p_booking_id': bookingId,
          'p_user_id': userId,
        });
      } catch (_) {
        await _supabase
            .from('chat_messages')
            .update({'is_read': true})
            .eq('booking_id', bookingId)
            .neq('sender_id', userId)
            .eq('is_read', false);
      }

      final bookingResponse = await _supabase
          .from('bookings')
          .select('unread_counts')
          .eq('id', bookingId)
          .maybeSingle();

      if (bookingResponse != null) {
        final Map<String, dynamic> unreadCounts = Map<String, dynamic>.from(
          bookingResponse['unread_counts'] ?? {}
        );
        unreadCounts[userId] = 0;

        await _supabase.from('bookings').update({
          'unread_counts': unreadCounts,
        }).eq('id', bookingId);
      }
    } catch (e) {
      VSPLogger.e('Error marking messages as read on Supabase', e);
    }
  }

  static Future<List<String>> getDeletedChatIds(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('deleted_chats_$userId') ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteConversationForUser(String bookingId, String userId, {String? contactId}) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String userKey = 'deleted_chats_$userId';
      final List<String> deletedList = prefs.getStringList(userKey) ?? [];
      if (!deletedList.contains(bookingId)) {
        deletedList.add(bookingId);
      }
      if (contactId != null && contactId.isNotEmpty && !deletedList.contains(contactId)) {
        deletedList.add(contactId);
      }
      await prefs.setStringList(userKey, deletedList);

      // Fast parallel update on chat_messages
      try {
        final messages = await _supabase
            .from('chat_messages')
            .select('id, deleted_for_users')
            .eq('booking_id', bookingId);

        if (messages.isNotEmpty) {
          await Future.wait(messages.map((msg) async {
            final String msgId = msg['id'].toString();
            final List<dynamic> currentDeleted = msg['deleted_for_users'] ?? [];
            final Set<String> updatedSet = currentDeleted.map((e) => e.toString()).toSet()..add(userId);

            await _supabase.from('chat_messages').update({
              'deleted_for_users': updatedSet.toList(),
            }).eq('id', msgId);
          }));
        }
      } catch (e) {
        VSPLogger.w('chat_messages delete notice: $e');
      }

      // Fast update on bookings
      try {
        final bookingResponse = await _supabase
            .from('bookings')
            .select('deleted_for_users')
            .eq('id', bookingId)
            .maybeSingle();

        if (bookingResponse != null) {
          final List<dynamic> currentDeleted = bookingResponse['deleted_for_users'] ?? [];
          final Set<String> updatedSet = currentDeleted.map((e) => e.toString()).toSet()..add(userId);

          await _supabase.from('bookings').update({
            'deleted_for_users': updatedSet.toList(),
          }).eq('id', bookingId);
        }
      } catch (e) {
        VSPLogger.w('bookings delete notice: $e');
      }
    } catch (e) {
      VSPLogger.e('Error deleting conversation for user $userId: ', e);
    }
  }

  Future<String?> _getValidStadiumId(String? ownerId) async {
    try {
      if (ownerId != null && ownerId.isNotEmpty) {
        final stadiumRes = await _supabase
            .from('stadiums')
            .select('id')
            .eq('owner_id', ownerId)
            .limit(1)
            .maybeSingle();
        if (stadiumRes != null && stadiumRes['id'] != null) {
          return stadiumRes['id'].toString();
        }
      }
      final anyStadium = await _supabase
          .from('stadiums')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (anyStadium != null && anyStadium['id'] != null) {
        return anyStadium['id'].toString();
      }
    } catch (e) {
      VSPLogger.w('Could not fetch stadium ID for chat thread: ');
    }
    return null;
  }

  Future<Map<String, dynamic>> getOrCreateSupportChat(String ownerId, bool isArabic) async {
    try {
      final existing = await _supabase
          .from('bookings')
          .select()
          .eq('notes', 'support_chat')
          .eq('owner_id', ownerId)
          .maybeSingle();

      if (existing != null) {
        return existing;
      }

      final stadiumId = await _getValidStadiumId(ownerId);
      final pastStart = DateTime.utc(2000, 1, 1).toIso8601String();
      final pastEnd = DateTime.utc(2000, 1, 1, 0, 0, 1).toIso8601String();

      final Map<String, dynamic> supportMap = {
        'user_id': ownerId,
        if (stadiumId != null) 'stadium_id': stadiumId,
        'stadium_name': isArabic ? 'الدعم الفني VSP' : 'VSP Support',
        'stadium_image_url': '',
        'owner_id': ownerId,
        'start_time': pastStart,
        'end_time': pastEnd,
        'booking_type': 'personal',
        'notes': 'support_chat',
        'status': 'confirmed',
        'created_by_user_id': ownerId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'joined_user_ids': [ownerId, '00000000-0000-0000-0000-000000000001'],
        'payment_method': 'cash',
        'total_price': 0.0,
        'current_players': 2,
        'is_paid': true,
        'payment_status': 'paid',
      };

      final response = await _supabase.from('bookings').insert(supportMap).select().maybeSingle();
      return response ?? supportMap;
    } on PostgrestException catch (e) {
      VSPLogger.e('Postgrest error in getOrCreateSupportChat: ', e);
      rethrow;
    } catch (e) {
      VSPLogger.e('Error in getOrCreateSupportChat', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOrCreateDirectChat(String currentUserId, String otherUserId, bool isArabic) async {
    try {
      final existing = await _supabase
          .from('bookings')
          .select()
          .eq('notes', 'chat_thread')
          .contains('joined_user_ids', [currentUserId, otherUserId])
          .maybeSingle();

      if (existing != null) {
        return existing;
      }

      final stadiumId = await _getValidStadiumId(currentUserId);
      final pastStart = DateTime.utc(2000, 1, 1).toIso8601String();
      final pastEnd = DateTime.utc(2000, 1, 1, 0, 0, 1).toIso8601String();

      final Map<String, dynamic> chatMap = {
        'user_id': currentUserId,
        if (stadiumId != null) 'stadium_id': stadiumId,
        'stadium_name': isArabic ? 'محادثة مباشرة' : 'Direct Chat',
        'stadium_image_url': '',
        'owner_id': currentUserId,
        'start_time': pastStart,
        'end_time': pastEnd,
        'booking_type': 'personal',
        'notes': 'chat_thread',
        'status': 'confirmed',
        'created_by_user_id': currentUserId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'joined_user_ids': [currentUserId, otherUserId],
        'payment_method': 'cash',
        'total_price': 0.0,
        'current_players': 2,
        'is_paid': true,
        'payment_status': 'paid',
      };

      final response = await _supabase.from('bookings').insert(chatMap).select().maybeSingle();
      return response ?? chatMap;
    } on PostgrestException catch (e) {
      VSPLogger.e('Postgrest error in getOrCreateDirectChat: ', e);
      rethrow;
    } catch (e) {
      VSPLogger.e('Error in getOrCreateDirectChat', e);
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamBookingsChats() {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .order('last_message_time', ascending: false)
        .map((list) => list);
  }

  Stream<int> streamTotalUnreadCount(String userId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map((list) {
          int total = 0;
          for (final booking in list) {
            final unreadMap = booking['unread_counts'];
            if (unreadMap is Map) {
              final count = unreadMap[userId];
              if (count is int && count > 0) total += count;
            }
          }
          return total;
        });
  }
}