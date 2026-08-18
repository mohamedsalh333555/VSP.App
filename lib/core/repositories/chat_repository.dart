import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../services/logger_service.dart';
import '../services/notification_handler.dart';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<ChatMessage>> getChatMessages(String conversationId, {String? currentUserId}) {
    try {
      return _supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .map((list) {
            try {
              final messages = list
                  .map((data) => ChatMessage.fromJson(data, data['id']?.toString() ?? ''))
                  .where((msg) => currentUserId == null || !msg.deletedForUsers.contains(currentUserId))
                  .toList();
              messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return messages;
            } catch (e) {
              VSPLogger.e('Error mapping chat messages list', e);
              return <ChatMessage>[];
            }
          })
          .handleError((error) {
            VSPLogger.e('Error in chat messages stream', error);
            return <ChatMessage>[];
          });
    } catch (e) {
      VSPLogger.e('Failed to initiate getChatMessages stream', e);
      return Stream.value(<ChatMessage>[]);
    }
  }

  Future<void> sendMessage(String conversationId, ChatMessage message) async {
    try {
      await _supabase.from('chat_messages').insert({
        'conversation_id': conversationId,
        'booking_id': conversationId, // Pass conversationId as booking_id to satisfy RLS policy
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'text': message.text,
        'created_at': message.timestamp.toUtc().toIso8601String(),
        'is_read': false,
        'is_edited': false,
        'deleted_for_users': [],
      });

      final conv = await _supabase
          .from('conversations')
          .select('participant_ids, unread_counts, booking_id')
          .eq('id', conversationId)
          .maybeSingle();

      if (conv != null) {
        final List<dynamic> participants = conv['participant_ids'] ?? [];
        final Map<String, dynamic> unreadCounts = Map<String, dynamic>.from(conv['unread_counts'] ?? {});

        for (var p in participants) {
          final pid = p.toString();
          if (pid != message.senderId) {
            unreadCounts[pid] = ((unreadCounts[pid] as int?) ?? 0) + 1;
          }
        }

        await _supabase.from('conversations').update({
          'last_message': message.text,
          'last_message_time': DateTime.now().toUtc().toIso8601String(),
          'unread_counts': unreadCounts,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', conversationId);

        final recipients = participants.map((e) => e.toString()).where((id) => id != message.senderId).toList();
        if (recipients.isNotEmpty) {
          await NotificationHandler.notifyNewChatMessage(
            recipientIds: recipients,
            senderName: message.senderName,
            messageText: message.text,
            bookingId: conv['booking_id']?.toString() ?? conversationId,
          );
        }
      }
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
      VSPLogger.e('Error editing message', e);
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      final conv = await _supabase
          .from('conversations')
          .select('unread_counts')
          .eq('id', conversationId)
          .maybeSingle();

      if (conv != null) {
        final Map<String, dynamic> unreadCounts = Map<String, dynamic>.from(conv['unread_counts'] ?? {});
        unreadCounts[userId] = 0;
        await _supabase.from('conversations').update({
          'unread_counts': unreadCounts,
        }).eq('id', conversationId);
      }
    } catch (e) {
      VSPLogger.e('Error marking messages as read', e);
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

  Future<void> deleteConversationForUser(String conversationId, String userId, {String? contactId}) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String userKey = 'deleted_chats_$userId';
      final List<String> deletedList = prefs.getStringList(userKey) ?? [];
      if (!deletedList.contains(conversationId)) deletedList.add(conversationId);
      if (contactId != null && contactId.isNotEmpty && !deletedList.contains(contactId)) {
        deletedList.add(contactId);
      }
      await prefs.setStringList(userKey, deletedList);

      final conv = await _supabase
          .from('conversations')
          .select('deleted_for_users')
          .eq('id', conversationId)
          .maybeSingle();

      if (conv != null) {
        final List<dynamic> current = conv['deleted_for_users'] ?? [];
        final set = current.map((e) => e.toString()).toSet()..add(userId);
        await _supabase.from('conversations').update({
          'deleted_for_users': set.toList(),
        }).eq('id', conversationId);
      }
    } catch (e) {
      VSPLogger.e('Error deleting conversation for user $userId', e);
    }
  }

  Future<Map<String, dynamic>> getOrCreateSupportChat(String userId, bool isArabic) async {
    try {
      final existing = await _supabase
          .from('conversations')
          .select()
          .eq('type', 'support')
          .contains('participant_ids', [userId])
          .maybeSingle();

      if (existing != null) return existing;

      final newConv = {
        'type': 'support',
        'title': isArabic ? 'الدعم الفني VSP' : 'VSP Support',
        'participant_ids': [userId],
        'unread_counts': {userId: 0},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _supabase.from('conversations').insert(newConv).select().single();
      return response;
    } catch (e) {
      VSPLogger.e('Error in getOrCreateSupportChat', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOrCreateDirectChat(String currentUserId, String otherUserId, bool isArabic) async {
    try {
      final existing = await _supabase
          .from('conversations')
          .select()
          .eq('type', 'direct')
          .contains('participant_ids', [currentUserId, otherUserId])
          .maybeSingle();

      if (existing != null) return existing;

      final newConv = {
        'type': 'direct',
        'title': isArabic ? 'محادثة مباشرة' : 'Direct Chat',
        'participant_ids': [currentUserId, otherUserId],
        'unread_counts': {currentUserId: 0, otherUserId: 0},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _supabase.from('conversations').insert(newConv).select().single();
      return response;
    } catch (e) {
      VSPLogger.e('Error in getOrCreateDirectChat', e);
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamUserConversations(String userId) {
    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .map((list) => list.where((c) {
              final parts = (c['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final deleted = (c['deleted_for_users'] as List?)?.map((e) => e.toString()).toList() ?? [];
              return parts.contains(userId) && !deleted.contains(userId);
            }).toList()
              ..sort((a, b) {
                final t1 = DateTime.parse(a['last_message_time'] ?? a['created_at']);
                final t2 = DateTime.parse(b['last_message_time'] ?? b['created_at']);
                return t2.compareTo(t1);
              }));
  }

  Stream<int> streamTotalUnreadCount(String userId) {
    return streamUserConversations(userId).map((list) {
      int total = 0;
      for (final conv in list) {
        final unreadMap = conv['unread_counts'];
        if (unreadMap is Map) {
          final count = unreadMap[userId];
          if (count is int && count > 0) total += count;
        }
      }
      return total;
    });
  }
}