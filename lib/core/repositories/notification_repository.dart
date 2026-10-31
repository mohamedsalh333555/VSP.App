import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class NotificationRepository {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  NotificationRepository({SupabaseClient? client}) : _client = client;

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
        .map((list) => list
            .map((data) => AppNotification.fromFirestore(_mapToCamelCase(data), data['id'].toString()))
            .toList());
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
      debugPrint('Error sending notification: $e');
    }
  }

  Future<bool> restoreNotification(String userId, AppNotification notification) async {
    try {
      final inserted = await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': notification.title,
        'body': notification.body,
        'type': notification.type,
        'is_read': notification.isRead,
        // Preserve the original timestamp when Undo restores a dismissed item.
        'created_at': notification.createdAt.toUtc().toIso8601String(),
        'booking_id': (notification.bookingId != null && notification.bookingId!.trim().isNotEmpty) ? notification.bookingId : null,
        'metadata': notification.metadata,
      }).select('id');
      return inserted.isNotEmpty;
    } catch (e) {
      debugPrint('Error restoring notification: $e');
      return false;
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

  Future<bool> deleteNotification(String userId, String notificationId) async {
    try {
      final deleted = await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', userId)
          .select('id');
      return deleted.isNotEmpty;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  Stream<int> getUnreadNotificationCount(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) => list.where((item) => item['is_read'] == false).length);
  }
}