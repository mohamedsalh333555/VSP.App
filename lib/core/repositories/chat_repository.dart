import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../services/logger_service.dart';
import '../services/notification_handler.dart';

class ChatRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Stream real-time chat messages for a specific booking from Supabase
  Stream<List<ChatMessage>> getChatMessages(String bookingId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .map((list) {
          // Map and sort descending (newest first) to match ListView.builder(reverse: true)
          final messages = list
              .map((data) => ChatMessage.fromJson(data, data['id'].toString()))
              .toList();
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return messages;
        });
  }

  /// Send message and dynamically increment unread counts on Supabase bookings table
  Future<void> sendMessage(String bookingId, ChatMessage message) async {
    try {
      // 1. Insert message to Supabase chat_messages
      await _supabase.from('chat_messages').insert({
        'booking_id': bookingId,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'text': message.text,
        'created_at': message.timestamp.toUtc().toIso8601String(),
      });

      // 2. Fetch current unread_counts and joined_user_ids to update them
      final bookingResponse = await _supabase
          .from('bookings')
          .select('joined_user_ids, unread_counts')
          .eq('id', bookingId)
          .maybeSingle();

      if (bookingResponse != null) {
        final List<dynamic> joinedIds = bookingResponse['joined_user_ids'] ?? [];
        final Map<String, dynamic> unreadCounts = Map<String, dynamic>.from(
          bookingResponse['unread_counts'] ?? {}
        );

        // Increment unread count for other participants
        for (var uid in joinedIds) {
          final String userId = uid.toString();
          if (userId != message.senderId) {
            final currentCount = (unreadCounts[userId] as int?) ?? 0;
            unreadCounts[userId] = currentCount + 1;
          }
        }

        // 3. Update bookings metadata
        await _supabase.from('bookings').update({
          'last_message': message.text,
          'last_message_time': DateTime.now().toUtc().toIso8601String(),
          'unread_counts': unreadCounts,
        }).eq('id', bookingId);

        // 4. Send notifications to other participants
        final List<String> otherParticipants = joinedIds
            .map((uid) => uid.toString())
            .where((uid) => uid != message.senderId)
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
    } catch (e) {
      VSPLogger.e('Error sending message on Supabase', e);
    }
  }

  /// Clear unread message count for a specific user in a booking
  Future<void> markMessagesAsRead(String bookingId, String userId) async {
    try {
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
}
