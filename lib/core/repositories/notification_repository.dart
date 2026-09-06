import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class NotificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  NotificationRepository();

  Map<String, dynamic> _mapToCamelCase(Map<String, dynamic> data) {
    return {
      'title': data['title'],
      'body': data['body'],
      'type': data['type'],
      'isRead': data['is_read'], 
      'createdAt': data['created_at'], 
      'bookingId': data['booking_id'], 
      'metadata': data['metadata'],
    };
  }

  Stream<List<AppNotification>> getUserNotifications(String userId, {int limit = 50}) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .map((list) => list
            .map((data) => AppNotification.fromFirestore(_mapToCamelCase(data), data['id'].toString()))
            .toList())
        .handleError((e) {
          debugPrint('Handled realtime error in getUserNotifications: $e');
        });
  }

  Future<void> sendNotification(String userId, AppNotification notification) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type,
        'is_read': notification.isRead,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'booking_id': (notification.bookingId != null && notification.bookingId!.trim().isNotEmpty) ? notification.bookingId : null,
        'metadata': notification.metadata,
      });
    } catch (e) {
      debugPrint('Error sending notification: ');
    }
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error marking notification as read: ');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all as read: ');
    }
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting notification: ');
    }
  }

  Stream<int> getUnreadNotificationCount(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) => list.where((item) => item['is_read'] == false).length);
  }

  Future<void> respondToChallenge(String userId, String notificationId, String bookingId, bool accept) async {
    try {
      await markNotificationAsRead(userId, notificationId);

      await _supabase
          .from('bookings')
          .update({'status': accept ? 'confirmed' : 'cancelled'})
          .eq('id', bookingId);
    } catch (e) {
      debugPrint('Error responding to challenge: ');
    }
  }
}