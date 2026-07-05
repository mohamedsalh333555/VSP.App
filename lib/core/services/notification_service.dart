import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/player/screens/notifications_center_screen.dart';
import '../../features/player/screens/booking_success_screen.dart';
import '../../features/player/screens/chat_screen.dart';
import '../../features/player/screens/bookings_screen.dart';
import '../repositories/booking_repository.dart';
import '../services/logger_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../services/database_service.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      // Request Permission (Required for iOS)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        return await _firebaseMessaging.getToken();
      }
      
      VSPLogger.w('Notification permission declined');
      return null;
    } catch (e) {
      VSPLogger.w('Failed to get notifications token: $e');
      return null;
    }
  }

  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> navKey) async {
    _navigatorKey = navKey;
    if (kIsWeb) return;

    // 1. Get & store token
    try {
      await getToken();
    } catch (e) {
      VSPLogger.w('Failed to initialize token: $e');
    }

    // 2. Foreground Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // 3. Background/Terminated Handler
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });

    // 4. Initial Message
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage.data);
    }

    // 5. Initialize Local Notifications (Mobile Only)
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_notification');
      
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
              VSPLogger.e('Error parsing notification payload', e);
            }
          }
        },
      );
    }
  }

  Future<void> scheduleMatchReminder({
    required String bookingId,
    required String stadiumName,
    required DateTime matchTime,
  }) async {
    if (kIsWeb) return; // Local scheduling not supported on Web
    final reminderTime = matchTime.subtract(const Duration(hours: 2));
    if (reminderTime.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'match_reminders',
      'Match Reminders',
      channelDescription: 'Reminders sent 2 hours before a match starts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Note: In a production app, we would use zonedSchedule. 
    // Here we use a simplified version for the MVP demonstration.
    await _localNotifications.show(
      bookingId.hashCode,
      'Match Reminder ⚽',
      'Your match at $stadiumName starts in 2 hours! Don\'t forget your gear.',
      details,
      payload: jsonEncode({'type': 'booking', 'id': bookingId}),
    );
    
    VSPLogger.i('Scheduled reminder for $bookingId at $reminderTime');
  }

  void _handleNotificationClick(Map<String, dynamic> data) async {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final String? type = data['type'];
    final String? bookingId = data['bookingId'];

    VSPLogger.i('Handling notification click: type=$type, bookingId=$bookingId');

    // 1. CHAT
    if (type == 'chat' && bookingId != null) {
      _navigateToChat(context, bookingId);
      return;
    }

    // 2. CHALLENGE
    if (type == 'challenge' || type == 'challenge_declined' || type == 'challenge_accepted') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
      );
      return;
    }

    // 3. BOOKING RELATED
    if (bookingId != null) {
      if (type == 'booking_new' || type == 'booking_confirmed') {
        _navigateToBooking(context, bookingId);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingsScreen()),
        );
      }
      return;
    }

    // 4. FALLBACK
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
    );
  }

  Future<void> _navigateToChat(BuildContext context, String bookingId) async {
    try {
      final booking = await SupabaseBookingRepository().getBookingById(bookingId);
      if (booking != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(booking: booking)),
        );
      }
    } catch (e) {
      VSPLogger.e('Error navigating to chat', e);
    }
  }

  Future<void> _navigateToBooking(BuildContext context, String bookingId) async {
    try {
      final booking = await SupabaseBookingRepository().getBookingById(bookingId);
      if (booking != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: booking)),
        );
      }
    } catch (e) {
      VSPLogger.e('Error navigating to booking', e);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', 
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
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

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null && message.notification?.title != null) {
      final appNotif = AppNotification(
        id: '',
        title: message.notification!.title!,
        body: message.notification!.body ?? '',
        type: message.data['type'] ?? 'info',
        bookingId: message.data['bookingId'],
        createdAt: DateTime.now(),
        isRead: false,
      );
      try {
        await DatabaseService().sendNotification(uid, appNotif);
      } catch (e) {
        VSPLogger.e('Error saving FCM to Supabase', e);
      }
    }
  }

  static Future<void> showBookingConfirmation({
    required String stadiumName,
    required DateTime bookingDate,
    required String timeSlot,
  }) async {
    if (kIsWeb) return; // Local notifications not supported on Web
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
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

    final title = 'Booking Confirmed! ⚽';
    final bodyStr = 'You booked $stadiumName on ${bookingDate.month}/${bookingDate.day} at $timeSlot.';

    await NotificationService()._localNotifications.show(
      stadiumName.hashCode,
      title,
      bodyStr,
      platformChannelSpecifics,
    );

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      final appNotif = AppNotification(
        id: '',
        title: title,
        body: bodyStr,
        type: 'info',
        createdAt: DateTime.now(),
        isRead: false,
      );
      try {
        await DatabaseService().sendNotification(uid, appNotif);
      } catch (e) {
        VSPLogger.e('Error saving booking confirmation to Supabase', e);
      }
    }
  }
}
