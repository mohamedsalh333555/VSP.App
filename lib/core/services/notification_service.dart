import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/player/screens/notifications_center_screen.dart';
import '../../features/player/screens/chat_screen.dart';
import '../services/logger_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../repositories/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification/notification_filter_service.dart';
import 'notification/notification_ui_helper.dart';

class NotificationService {
 static final NotificationService _instance = NotificationService._internal();
 factory NotificationService() => _instance;
 NotificationService._internal();

 FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
 final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
 StreamSubscription<AuthState>? _authStateSubscription;
 StreamSubscription<String>? _tokenRefreshSubscription;
 StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
 StreamSubscription<RemoteMessage>? _openedMessageSubscription;
 String? _latestFcmToken;

 Future<void> dispose() async {
   await _authStateSubscription?.cancel();
   _authStateSubscription = null;
   await _tokenRefreshSubscription?.cancel();
   _tokenRefreshSubscription = null;
   await _foregroundMessageSubscription?.cancel();
   _foregroundMessageSubscription = null;
   await _openedMessageSubscription?.cancel();
   _openedMessageSubscription = null;
   stopRealtimeNotificationsListener();
 }

 Future<String?> getToken() async {
   if (kIsWeb) return null;
   try {
     NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();
     if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
       settings = await _firebaseMessaging.requestPermission(alert: true, badge: true, sound: true);
     }
     if (settings.authorizationStatus == AuthorizationStatus.authorized ||
         settings.authorizationStatus == AuthorizationStatus.provisional) {
       return await _firebaseMessaging.getToken();
     }
     VSPLogger.w('Notification permission is disabled/declined; no repeated prompt.');
     return null;
   } catch (e) {
     VSPLogger.w('Failed to get notifications token: $e');
     return null;
   }
 }

 GlobalKey<NavigatorState>? _navigatorKey;

 Future<void> _storeDeviceToken(String userId, String token) async {
   if (token.trim().isEmpty) return;
   final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
   await Supabase.instance.client.from('user_device_tokens').upsert({
     'token': token.trim(),
     'user_id': userId,
     'platform': platform,
     'updated_at': DateTime.now().toUtc().toIso8601String(),
   }, onConflict: 'token');
 }

 Future<void> _registerTokenForUser(String userId, String token) async {
   await _storeDeviceToken(userId, token);
   await Supabase.instance.client.from('users').update({'fcm_token': token.trim()}).eq('id', userId);
   VSPLogger.i('Registered FCM token for signed-in user.');
 }

 Future<void> initialize(GlobalKey<NavigatorState> navKey) async {
   _navigatorKey = navKey;
   if (kIsWeb) return;
   try {
     _latestFcmToken = await getToken();
     final user = Supabase.instance.client.auth.currentUser;
     if (_latestFcmToken != null && user != null) await _registerTokenForUser(user.id, _latestFcmToken!);
   } catch (e) {
     VSPLogger.w('Failed to initialize FCM token: $e');
   }

   _authStateSubscription ??= Supabase.instance.client.auth.onAuthStateChange.listen((authState) async {
     final user = authState.session?.user ?? Supabase.instance.client.auth.currentUser;
     if (user == null) return;
     try {
       final token = _latestFcmToken ?? await getToken();
       _latestFcmToken = token;
       if (token != null) await _registerTokenForUser(user.id, token);
     } catch (e) {
       VSPLogger.w('Failed to register FCM token after authentication: $e');
     }
   });

   _tokenRefreshSubscription ??= _firebaseMessaging.onTokenRefresh.listen((newToken) async {
     _latestFcmToken = newToken;
     final user = Supabase.instance.client.auth.currentUser;
     if (user == null) return;
     try {
       await _registerTokenForUser(user.id, newToken);
     } catch (e) {
       VSPLogger.w('Failed to update refreshed FCM token: $e');
     }
   });

   _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
     final bookingId = message.data['bookingId']?.toString();
     final type = message.data['type']?.toString();
     if (type == 'chat' && ChatScreen.activeBookingId == bookingId) return;
     if (!await _shouldShowNotification(type)) return;
     if (message.notification != null) {
       await _showLocalNotification(message);
       NotificationUiHelper.showInAppAlert(context: _navigatorKey?.currentContext, message: message);
     }
   });

   _openedMessageSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     _handleNotificationClick(message.data);
   });

   final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
   if (initialMessage != null) _handleNotificationClick(initialMessage.data);

   const initializationSettings = InitializationSettings(
     android: AndroidInitializationSettings('@mipmap/ic_launcher'),
     iOS: DarwinInitializationSettings(
       requestAlertPermission: true,
       requestBadgePermission: true,
       requestSoundPermission: true,
     ),
   );
   await _localNotifications.initialize(
     initializationSettings,
     onDidReceiveNotificationResponse: (NotificationResponse response) {
       if (response.payload != null) {
         try {
           _handleNotificationClick(jsonDecode(response.payload!) as Map<String, dynamic>);
         } catch (e) {
           VSPLogger.e('Error parsing notification payload', e);
         }
       }
     },
   );

   final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
   if (androidPlugin != null) {
     try {
       final enabled = await androidPlugin.areNotificationsEnabled();
       if (enabled == false) VSPLogger.w('Android notifications are disabled; respecting the OS setting.');
     } catch (e) {
       VSPLogger.w('Could not read Android notification permission state: $e');
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

 Future<void> scheduleMatchReminder({required String bookingId, required String stadiumName, required DateTime matchTime}) async {
   if (kIsWeb) return;
   final prefs = await SharedPreferences.getInstance();
   if (!(prefs.getBool('notif_general') ?? true) || !(prefs.getBool('notif_match_reminders') ?? true)) return;
   final reminderTime = matchTime.subtract(const Duration(hours: 2));
   if (reminderTime.isBefore(DateTime.now())) return;
   const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
     'match_reminders', 'Match Reminders',
     channelDescription: 'Reminders sent 2 hours before a match starts',
     importance: Importance.high, priority: Priority.high,
   );
   await _localNotifications.show(
     bookingId.hashCode, 'Match Reminder',
     'Your match at $stadiumName starts in 2 hours! Don\'t forget your gear.',
     const NotificationDetails(android: androidDetails),
     payload: jsonEncode({'type': 'booking', 'id': bookingId}),
   );
   VSPLogger.i('Scheduled reminder for $bookingId at $reminderTime');
 }

 void _handleNotificationClick(Map<String, dynamic> data) async {
   final context = _navigatorKey?.currentContext;
   if (context == null) return;
   final type = data['type']?.toString();
   final bookingId = (data['bookingId'] ?? data['booking_id'])?.toString();
   final teamId = (data['teamId'] ?? data['team_id'])?.toString();
   final tournamentId = (data['tournamentId'] ?? data['tournament_id'] ?? data['championship_id'] ?? data['championshipId'])?.toString();
   VSPLogger.i('Handling notification click: type=$type, bookingId=$bookingId, teamId=$teamId, tournamentId=$tournamentId');
   if (bookingId != null && bookingId.isNotEmpty) {
     if (type == 'chat') {
       NotificationUiHelper.navigateToChat(context, bookingId);
       return;
     }
     try {
       GoRouter.of(context).push('/match/$bookingId');
       return;
     } catch (_) {
       NotificationUiHelper.navigateToBooking(context, bookingId);
       return;
     }
   }
   if (teamId != null && teamId.isNotEmpty) {
     try { GoRouter.of(context).push('/team/$teamId'); return; } catch (_) {}
   }
   if (tournamentId != null && tournamentId.isNotEmpty) {
     try { GoRouter.of(context).push('/championship/$tournamentId'); return; } catch (_) {}
   }
   if (type == 'subscription') {
     try { GoRouter.of(context).push('/subscription-plans'); return; } catch (_) {}
   }
   if (type == 'payout' || type == 'ledger') {
     try { GoRouter.of(context).push('/owner-ledger'); return; } catch (_) {}
   }
   try {
     GoRouter.of(context).push('/notifications');
   } catch (_) {
     Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()));
   }
 }

 Future<void> _showLocalNotification(RemoteMessage message) async {
   const androidDetails = AndroidNotificationDetails(
     'vsp_default_channel',
     'VSP General Notifications',
     importance: Importance.max,
     priority: Priority.high,
     icon: 'ic_notification',
   );
   const details = NotificationDetails(
     android: androidDetails,
     iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
   );
   await _localNotifications.show(
     message.hashCode,
     message.notification?.title,
     message.notification?.body,
     details,
     payload: jsonEncode(message.data),
   );
 }

 static Future<void> showBookingConfirmation({required String stadiumName, required DateTime bookingDate, required String timeSlot}) async {
   if (kIsWeb) return;
   final prefs = await SharedPreferences.getInstance();
   if (!(prefs.getBool('notif_general') ?? true) || !(prefs.getBool('notif_cash_bookings') ?? true)) return;
   const androidDetails = AndroidNotificationDetails(
     'booking_channel', 'Booking Notifications',
     importance: Importance.max, priority: Priority.high, icon: 'ic_notification',
   );
   const darwinDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
   const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);
   const title = 'Booking Confirmed!';
   final bodyStr = 'You booked $stadiumName on ${bookingDate.month}/${bookingDate.day} at $timeSlot.';
   await NotificationService()._localNotifications.show(stadiumName.hashCode, title, bodyStr, details);
   final uid = Supabase.instance.client.auth.currentUser?.id;
   if (uid != null) {
     final appNotif = AppNotification(id: '', title: title, body: bodyStr, type: 'info', createdAt: DateTime.now(), isRead: false);
     try { await NotificationRepository().sendNotification(uid, appNotif); }
     catch (e) { VSPLogger.e('Error saving booking confirmation to Supabase', e); }
   }
 }

 Future<bool> _shouldShowNotification(String? type) async {
   final prefs = await SharedPreferences.getInstance();
   final hasOwnerToggles = prefs.containsKey('notif_owner_new_bookings') || prefs.containsKey('notif_owner_payouts');
   return NotificationFilterService.shouldShowNotification(type, isOwner: hasOwnerToggles, prefs: prefs);
 }

 RealtimeChannel? _realtimeNotifChannel;

 void listenToRealtimeNotifications(String userId) {
   stopRealtimeNotificationsListener();
   VSPLogger.i('Subscribing to Supabase Realtime Notifications for user: $userId');
   _realtimeNotifChannel = Supabase.instance.client
       .channel('public:notifications:user_id=eq.$userId')
       .onPostgresChanges(
         event: PostgresChangeEvent.insert,
         schema: 'public',
         table: 'notifications',
         filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
         callback: (payload) async {
           final record = payload.newRecord;
           if (record.isEmpty || !await _shouldShowNotification(record['type']?.toString())) return;
           const androidDetails = AndroidNotificationDetails(
             'vsp_default_channel', 'VSP General Notifications',
             importance: Importance.max, priority: Priority.high, icon: 'ic_notification',
             enableVibration: true, playSound: true,
           );
           const details = NotificationDetails(
             android: androidDetails,
             iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
           );
           await _localNotifications.show(
             record['id'].hashCode,
             record['title']?.toString() ?? 'إشعار جديد',
             record['body']?.toString() ?? '',
             details,
             payload: jsonEncode({
               'type': record['type']?.toString() ?? 'info',
               if (record['booking_id'] != null) 'bookingId': record['booking_id'].toString(),
               if (record['team_id'] != null) 'teamId': record['team_id'].toString(),
               if (record['tournament_id'] != null) 'tournamentId': record['tournament_id'].toString(),
             }),
           );
         },
       );
   _realtimeNotifChannel!.subscribe();
 }

 void stopRealtimeNotificationsListener() {
   if (_realtimeNotifChannel != null) {
     Supabase.instance.client.removeChannel(_realtimeNotifChannel!);
     _realtimeNotifChannel = null;
   }
 }
}
