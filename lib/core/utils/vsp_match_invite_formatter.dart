import 'package:flutter/material.dart';
import '../utils/vsp_launcher_utils.dart';
import 'app_date_formatter.dart';
import '../services/sharing_service.dart';

class VSPMatchInviteFormatter {
 /// Generate a clean, attractive WhatsApp match invitation message
 static String buildInviteMessage({
 required String stadiumName,
 required String bookingId,
 required DateTime startTime,
 required DateTime endTime,
 String? googleMapsUrl,
 String? governorate,
 int? currentPlayers,
 int? maxPlayers,
 double? costPerPerson,
 double? totalPrice,
 String? hostName,
 bool isArabic = true,
 }) {
 final dateStr = AppDateFormatter.formatDayMonth(startTime, isArabic ? 'ar' : 'en');
 final timeStr = '${AppDateFormatter.formatTime(startTime, isArabic ? 'ar' : 'en')} - ${AppDateFormatter.formatTime(endTime, isArabic ? 'ar' : 'en')}';
 final matchLink = SharingService.getMatchLink(bookingId);
 
 final mapsLine = (googleMapsUrl != null && googleMapsUrl.isNotEmpty)
 ? (isArabic ? ' *الموقع على الخريطة:* $googleMapsUrl\n' : ' *Map Location:* $googleMapsUrl\n')
 : '';

 int needed = 0;
 if (maxPlayers != null && currentPlayers != null && maxPlayers > currentPlayers) {
 needed = maxPlayers - currentPlayers;
 }

 final String neededStr = needed > 0 
 ? (isArabic ? ' *العدد المطلوب:* ناقص $needed لاعيبة! \n' : ' *Players Needed:* $needed more players needed! \n')
 : '';

 final String costStr = (costPerPerson != null && costPerPerson > 0)
 ? (isArabic ? ' *حساب الفرد:* ${costPerPerson.toInt()} ج.م\n' : ' *Per Player:* ${costPerPerson.toInt()} EGP\n')
 : (totalPrice != null && totalPrice > 0 
 ? (isArabic ? ' *إجمالي الحجز:* ${totalPrice.toInt()} ج.م\n' : ' *Total Price:* ${totalPrice.toInt()} EGP\n') 
 : '');

 final String hostStr = (hostName != null && hostName.isNotEmpty)
 ? (isArabic ? ' *تنظيم الكابتن:* $hostName\n' : ' *Organized by:* $hostName\n')
 : '';

 if (isArabic) {
 return '''
 *دعوة لمباراة كرة قدم — VSP* 

 *الملعب:* $stadiumName
 *اليوم:* $dateStr
 *الميعاد:* $timeStr
$hostStr$neededStr$costStr$mapsLine
 *سجل اسمك وأكد نزولك للماتش عبر الرابط:*
$matchLink
'''.trim();
 } else {
 return '''
 *VSP Football Match Invite!* 

 *Pitch:* $stadiumName
 *Date:* $dateStr
 *Time:* $timeStr
$hostStr$neededStr$costStr$mapsLine
 *Confirm and join the match here:*
$matchLink
'''.trim();
 }
 }

 /// Launch WhatsApp directly with the pre-filled match invite
 static Future<void> shareToWhatsApp({
 required BuildContext context,
 required String message,
 String? phone,
 }) async {
 await VSPLauncherUtils.openWhatsApp(
 context,
 phone: phone ?? '',
 message: message,
 );
 }
}
