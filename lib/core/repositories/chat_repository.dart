import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../models/chat_model.dart';
import '../services/notification_handler.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ChatMessage>> getChatMessages(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendMessage(String bookingId, ChatMessage message) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Add Message
      final messageRef = _firestore
          .collection('bookings')
          .doc(bookingId)
          .collection('messages')
          .doc();
      batch.set(messageRef, message.toFirestore());
      
      // 2. Fetch participants for unread increment
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      final participants = List<String>.from(bookingDoc.data()?['joinedUserIds'] ?? []);
      
      Map<String, dynamic> unreadUpdates = {};
      for (var uid in participants) {
        if (uid != message.senderId) {
          unreadUpdates['unreadCounts.$uid'] = FieldValue.increment(1);
        }
      }

      // 3. Update summary
      batch.update(_firestore.collection('bookings').doc(bookingId), {
        'lastMessage': message.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        ...unreadUpdates,
      });

      await batch.commit();

      // 4. Send Notifications to others
      final otherParticipants = participants.where((uid) => uid != message.senderId).toList();
      if (otherParticipants.isNotEmpty) {
        String senderName = 'A player';
        try {
          final senderDoc = await _firestore.collection('users').doc(message.senderId).get();
          if (senderDoc.exists) {
            senderName = senderDoc.data()?['name'] ?? 'A player';
          }
        } catch (_) {}

        await NotificationHandler.notifyNewChatMessage(
          recipientIds: otherParticipants,
          senderName: senderName,
          messageText: message.text,
          bookingId: bookingId,
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// Mark all messages as read for a specific user in a booking
  Future<void> markMessagesAsRead(String bookingId, String userId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'unreadCounts.$userId': 0,
      });
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
}
