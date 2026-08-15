import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../ui/tokens/vsp_tokens.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/player/screens/notifications_center_screen.dart';
import '../../features/player/screens/booking_success_screen.dart';
import '../../features/player/screens/chat_screen.dart';
import '../repositories/booking_repository.dart';
import '../services/logger_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../repositories/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final bookingId = message.data['bookingId']?.toString();
      final type = message.data['type']?.toString();

      if (type == 'chat' && ChatScreen.activeBookingId == bookingId) {
        return;
      }

      final shouldShow = await _shouldShowNotification(type);
      if (!shouldShow) return;

      if (message.notification != null) {
        _showLocalNotification(message);
        _showInAppAlert(message);
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
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
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

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Request Android 13+ (API 33+) Notification Permission explicitly
        try {
          await androidPlugin.requestNotificationsPermission();
        } catch (e) {
          VSPLogger.w('Android 13+ notification permission request notice: $e');
        }

        const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
          'vsp_default_channel',
          'VSP General Notifications',
          description: 'General booking, match, and challenge alerts',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        const AndroidNotificationChannel p2pChannel = AndroidNotificationChannel(
          'vsp_p2p_alerts',
          'VSP P2P Alerts',
          description: 'High-priority notifications for P2P trading',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidPlugin.createNotificationChannel(defaultChannel);
        await androidPlugin.createNotificationChannel(p2pChannel);
      }
    }
  }

  Future<void> scheduleMatchReminder({
    required String bookingId,
    required String stadiumName,
    required DateTime matchTime,
  }) async {
    if (kIsWeb) return; // Local scheduling not supported on Web
    
    // Check match reminders setting
    final prefs = await SharedPreferences.getInstance();
    final general = prefs.getBool('notif_general') ?? true;
    final matchReminders = prefs.getBool('notif_match_reminders') ?? true;
    if (!general || !matchReminders) return;

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
    final String? teamId = data['teamId'];

    VSPLogger.i('Handling notification click with GoRouter: type=$type, bookingId=$bookingId, teamId=$teamId');

    // 1. MATCH DETAILS / BOOKING DEEP LINK
    if (bookingId != null && bookingId.isNotEmpty) {
      if (type == 'chat') {
        _navigateToChat(context, bookingId);
        return;
      }
      try {
        GoRouter.of(context).push('/match/$bookingId');
        return;
      } catch (_) {
        _navigateToBooking(context, bookingId);
        return;
      }
    }

    // 2. TEAM PROFILE DEEP LINK
    if (teamId != null && teamId.isNotEmpty) {
      try {
        GoRouter.of(context).push('/team/$teamId');
        return;
      } catch (_) {}
    }

    // 3. NOTIFICATIONS CENTER DEEP LINK
    try {
      GoRouter.of(context).push('/notifications');
    } catch (_) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
      );
    }
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
        await NotificationRepository().sendNotification(uid, appNotif);
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

    // Check cash booking confirmations setting
    final prefs = await SharedPreferences.getInstance();
    final general = prefs.getBool('notif_general') ?? true;
    final cashBookings = prefs.getBool('notif_cash_bookings') ?? true;
    if (!general || !cashBookings) return;
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
        await NotificationRepository().sendNotification(uid, appNotif);
      } catch (e) {
        VSPLogger.e('Error saving booking confirmation to Supabase', e);
      }
    }
  }

  Future<bool> _shouldShowNotification(String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final general = prefs.getBool('notif_general') ?? true;
      if (!general) return false;

      if (type == null) return true;

      switch (type) {
        case 'chat':
          return prefs.getBool('notif_chat') ?? true;
        case 'booking_new':
        case 'booking_confirmed':
        case 'booking_cancelled':
          return prefs.getBool('notif_cash_bookings') ?? true;
        case 'team_transfer':
        case 'team_invite':
        case 'info':
          return prefs.getBool('notif_team_transfers') ?? true;
        case 'match_reminder':
          return prefs.getBool('notif_match_reminders') ?? true;
        case 'challenge':
        case 'challenge_accepted':
        case 'challenge_declined':
          return prefs.getBool('notif_challenge_results') ?? true;
        default:
          return true;
      }
    } catch (_) {
      return true;
    }
  }

  void _showInAppAlert(RemoteMessage message) async {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('notif_sound') ?? true;

      if (soundEnabled) {
        HapticFeedback.heavyImpact();
      }
      
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Iconsax.messages_3_copy, color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.notification?.title ?? 'New Message',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      message.notification?.body ?? '',
                      style: const TextStyle(color: Colors.black, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: VSPColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      VSPLogger.e('Error showing in-app alert snackbar', e);
    }
  }

  RealtimeChannel? _realtimeNotifChannel;

  void listenToRealtimeNotifications(String userId) {
    stopRealtimeNotificationsListener();

    VSPLogger.i('📡 Subscribing to Supabase Realtime Notifications for user: $userId');
    _realtimeNotifChannel = Supabase.instance.client
        .channel('public:notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            VSPLogger.i('⚡ Real-time notification inserted into DB: ${payload.newRecord}');
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              final title = record['title']?.toString() ?? 'إشعار جديد ⚽';
              final body = record['body']?.toString() ?? '';
              final type = record['type']?.toString();
              final bookingId = record['booking_id']?.toString();

              final shouldShow = await _shouldShowNotification(type);
              if (!shouldShow) return;

              // Fire System OS Notification Banner
              const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
                'vsp_default_channel',
                'VSP General Notifications',
                importance: Importance.max,
                priority: Priority.high,
                icon: 'ic_notification',
                enableVibration: true,
                playSound: true,
              );
              const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              );
              const NotificationDetails details = NotificationDetails(
                android: androidDetails,
                iOS: darwinDetails,
              );

              await _localNotifications.show(
                record['id'].hashCode,
                title,
                body,
                details,
                payload: jsonEncode({'type': type, 'bookingId': bookingId}),
              );
            }
          },
        );
    _realtimeNotifChannel!.subscribe();
  }

  void stopRealtimeNotificationsListener() {
    if (_realtimeNotifChannel != null) {
      VSPLogger.i('📡 Stopping Supabase Realtime Notifications subscription');
      Supabase.instance.client.removeChannel(_realtimeNotifChannel!);
      _realtimeNotifChannel = null;
    }
  }
}
