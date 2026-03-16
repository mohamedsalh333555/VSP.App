import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/player/screens/notifications_center_screen.dart';
import '../../features/player/screens/booking_success_screen.dart';
import '../repositories/booking_repository.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<String?> getToken() async {
    // Request Permission (Required for iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      return await _firebaseMessaging.getToken();
    }
    
    debugPrint('Notification permission declined');
    return null;
  }

  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> navKey) async {
    _navigatorKey = navKey;

    // 1. Get & store token (not logged — tokens are device credentials)
    getToken();

    // 2. Foreground Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Show local notification
        _showLocalNotification(message);
      }
    });

    // 3. Background/Terminated Handler (App opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });

    // 4. Initial Message (App launched from notification while terminated)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage.data);
    }

    // 5. Initialize Local Notifications Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_logo');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );
  }

  void _handleNotificationClick(Map<String, dynamic> data) async {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final type = data['type'];
    final bookingId = data['bookingId'];

    if (type == 'challenge') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
      );
    } else if (bookingId != null) {
      // Fetch booking and navigate to success/details
      try {
        final booking = await FirestoreBookingRepository().getBookingById(bookingId);
        if (booking != null && context.mounted) {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: booking)),
          );
        }
      } catch (e) {
        debugPrint('Error navigating to booking: $e');
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', 
      'High Importance Notifications',
      icon: '@drawable/ic_stat_logo',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }
  static Future<void> showBookingConfirmation({
    required String stadiumName,
    required DateTime bookingDate,
    required String timeSlot,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      icon: '@drawable/ic_stat_logo',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await NotificationService()._localNotifications.show(
      stadiumName.hashCode,
      'Booking Confirmed! ⚽',
      'You booked $stadiumName on ${bookingDate.month}/${bookingDate.day} at $timeSlot.',
      platformChannelSpecifics,
    );
  }
}
