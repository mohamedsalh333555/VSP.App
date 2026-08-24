import 'package:firebase_analytics/firebase_analytics.dart';
import 'logger_service.dart';

class AnalyticsService {
 static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
 static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: _analytics);

 static Future<void> logEvent({
 required String name,
 Map<String, Object>? parameters,
 }) async {
 try {
 await _analytics.logEvent(name: name, parameters: parameters);
 VSPLogger.i(' Analytics Event: $name | $parameters');
 } catch (e) {
 VSPLogger.e(' Analytics Error: $e');
 }
 }

 static Future<void> setUserProperties({
 required String userId,
 String? role,
 String? governorate,
 }) async {
 await _analytics.setUserId(id: userId);
 if (role != null) await _analytics.setUserProperty(name: 'user_role', value: role);
 if (governorate != null) await _analytics.setUserProperty(name: 'governorate', value: governorate);
 }

 // Specific events
 static Future<void> logMatchJoined(String bookingId, String type) async {
 await logEvent(name: 'match_joined', parameters: {
 'booking_id': bookingId,
 'type': type,
 });
 }

 static Future<void> logStadiumBooked(String stadiumId, double price) async {
 await logEvent(name: 'stadium_booked', parameters: {
 'stadium_id': stadiumId,
 'price': price,
 });
 }

 static Future<void> logChallengeSent(String fromTeam, String toTeam) async {
 await logEvent(name: 'challenge_sent', parameters: {
 'from_team': fromTeam,
 'to_team': toTeam,
 });
 }

 static Future<void> logRankUp(int oldRank, int newRank) async {
 await logEvent(name: 'rank_up', parameters: {
 'old_rank': oldRank,
 'new_rank': newRank,
 });
 }

 static Future<void> logChatMessageSent(String type) async {
 await logEvent(name: 'chat_message_sent', parameters: {
 'message_type': type,
 });
 }
}
