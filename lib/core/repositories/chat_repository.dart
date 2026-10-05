import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../services/logger_service.dart';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<ChatMessage>> getChatMessages(String conversationId, {String? currentUserId}) {
    final streamQuery = _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId);

    return streamQuery.map((list) {
      final messages = list
          .map((data) => ChatMessage.fromJson(data, data['id']?.toString() ?? ''))
          .where((msg) => currentUserId == null || !msg.deletedForUsers.contains(currentUserId))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    }).handleError((error) {
      VSPLogger.e('Error in chat messages stream', error);
    });
  }

  Future<Map<String, dynamic>> sendMessage(String conversationId, ChatMessage message) async {
    final response = await _supabase.rpc('send_chat_message_atomic', params: {
      'p_conversation_id': conversationId,
      'p_text': message.text,
    });
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('MESSAGE_SEND_FAILED');
  }

  Future<bool> canWriteConversation(String conversationId) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return false;
      final result = await _supabase.rpc('vsp_chat_write_allowed', params: {
        'p_conversation_id': conversationId,
        'p_user_id': uid,
      });
      return result == true;
    } catch (e) {
      VSPLogger.w('Unable to determine chat write state: $e');
      return false;
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    final res = await _supabase.rpc('edit_chat_message_atomic', params: {
      'p_message_id': messageId,
      'p_new_text': newText,
    });
    if (res is Map && res['success'] == false) {
      throw Exception(res['error']?.toString() ?? 'MESSAGE_EDIT_FAILED');
    }
  }

  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      await _supabase.rpc('mark_chat_messages_as_read', params: {
        'p_conversation_id': conversationId,
        'p_user_id': userId,
      });
    } catch (e) {
      VSPLogger.e('Error marking messages as read', e);
    }
  }

  Future<void> deleteConversationForUser(String conversationId, String userId) async {
    if (userId.isEmpty) return;
    await _supabase.rpc('delete_chat_for_user', params: {
      'p_conversation_id': conversationId,
      'p_user_id': userId,
    });
  }

  Future<Map<String, dynamic>> getOrCreateDirectChat({
    required String otherUserId,
    required bool isArabic,
    required String contextType,
    required String contextId,
  }) async {
    final response = await _supabase.rpc('create_direct_chat_atomic', params: {
      'p_other_user_id': otherUserId,
      'p_context_type': contextType,
      'p_context_id': contextId,
    });
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('DIRECT_CHAT_CREATE_FAILED');
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String category,
    String? contextType,
    String? contextId,
    String? bookingId,
    String priority = 'normal',
  }) async {
    final response = await _supabase.rpc('create_support_ticket_atomic', params: {
      'p_subject': subject,
      'p_category': category,
      'p_context_type': contextType,
      'p_context_id': contextId,
      'p_booking_id': bookingId,
      'p_priority': priority,
    });
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('SUPPORT_TICKET_CREATE_FAILED');
  }

  Future<Map<String, dynamic>> sendSupportTicketMessage({
    required String ticketId,
    required String body,
  }) async {
    final response = await _supabase.rpc('send_support_ticket_message_atomic', params: {
      'p_ticket_id': ticketId,
      'p_body': body,
    });
    if (response is Map) return Map<String, dynamic>.from(response);
    throw Exception('SUPPORT_MESSAGE_SEND_FAILED');
  }

  Future<void> markSupportTicketWhatsAppEscalated(String ticketId) async {
    await _supabase.rpc('mark_support_ticket_whatsapp_escalation', params: {
      'p_ticket_id': ticketId,
    });
  }

  Stream<List<Map<String, dynamic>>> streamSupportTickets(String userId) {
    return _supabase
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .eq('requester_id', userId)
        .order('updated_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamSupportTicketMessages(String ticketId) {
    return _supabase
        .from('support_ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
  }

  Stream<List<Map<String, dynamic>>> streamUserConversations(String userId) {
    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('type', 'direct')
        .map((list) => list.where((c) {
              final parts = (c['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final deleted = (c['deleted_for_users'] as List?)?.map((e) => e.toString()).toList() ?? [];
              return parts.contains(userId) &&
                  !deleted.contains(userId) &&
                  (c['context_id']?.toString().isNotEmpty ?? false);
            }).toList()
              ..sort((a, b) {
                final aRaw = a['last_message_time'] ?? a['created_at'];
                final bRaw = b['last_message_time'] ?? b['created_at'];
                final t1 = DateTime.tryParse(aRaw?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                final t2 = DateTime.tryParse(bRaw?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                return t2.compareTo(t1);
              }));
  }

  Stream<int> streamTotalUnreadCount(String userId) {
    return streamUserConversations(userId).map((list) {
      var total = 0;
      for (final conv in list) {
        final unreadMap = conv['unread_counts'];
        if (unreadMap is Map) {
          final value = unreadMap[userId];
          if (value is int && value > 0) total += value;
        }
      }
      return total;
    });
  }
}
