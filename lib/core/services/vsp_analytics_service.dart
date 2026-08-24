import 'package:flutter/foundation.dart';

class VSPAnalyticsService {
 static final VSPAnalyticsService _instance = VSPAnalyticsService._internal();

 factory VSPAnalyticsService() => _instance;

 VSPAnalyticsService._internal();

 /// تسجيل الأنشطة والأحداث التنافسية والتشغيلية في VSP
 void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
 if (kDebugMode) {
 debugPrint(' [VSP Analytics Event] -> $eventName | Parameters: $parameters');
 }
 }

 void logChallengeCreated({required String challengeId, required String governorate}) {
 logEvent('challenge_created', parameters: {
 'challenge_id': challengeId,
 'governorate': governorate,
 'timestamp': DateTime.now().toIso8601String(),
 });
 }

 void logChallengeAccepted({required String challengeId, required String teamId}) {
 logEvent('challenge_accepted', parameters: {
 'challenge_id': challengeId,
 'accepted_team_id': teamId,
 'timestamp': DateTime.now().toIso8601String(),
 });
 }

 void logMatchResultSubmitted({required String matchId, required String score}) {
 logEvent('match_result_submitted', parameters: {
 'match_id': matchId,
 'score': score,
 'timestamp': DateTime.now().toIso8601String(),
 });
 }

 void logBookingCompleted({required String bookingId, required double amount}) {
 logEvent('booking_completed', parameters: {
 'booking_id': bookingId,
 'amount': amount,
 'timestamp': DateTime.now().toIso8601String(),
 });
 }
}
