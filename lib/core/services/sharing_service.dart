import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import '../utils/app_date_formatter.dart';

class SharingService {
 // Base URL for deep linking
 static const String _baseUrl = 'https://vsp.app';

 /// Generate a link for a specific match/booking
 static String getMatchLink(String bookingId) {
 return '$_baseUrl/match/$bookingId';
 }

 /// Generate a link for a specific team
 static String getTeamLink(String teamId) {
 return '$_baseUrl/team/$teamId';
 }

 /// Share match details via native share sheet
 static Future<void> shareMatch({
 required String bookingId,
 required String teamName,
 required String stadiumName,
 required String date,
 }) async {
 final link = getMatchLink(bookingId);
 final text = ' انضم لمباراتنا على تطبيق VSP!\n\n'
 ' الملعب: $stadiumName\n'
 ' الفريق: $teamName\n'
 ' الموعد: $date\n\n'
 ' رابط تأكيد الحضور والمباراة:\n$link';

 await SharePlus.instance.share(ShareParams(text: text, subject: 'مباراة كرة قدم على VSP'));
 }

 /// Share match details directly via formatted text
 static Future<void> shareMatchFormatted(String formattedMessage) async {
 await SharePlus.instance.share(ShareParams(
 text: formattedMessage,
 subject: 'دعوة مباراة كرة قدم — VSP',
 ));
 }

 /// Share championship details with rich dynamic info
 static Future<void> shareChampionship({
 required String id,
 required String name,
 String? startDateStr,
 String? endDateStr,
 double grandPrize = 0,
 double entryFee = 0,
 int joinedTeamsCount = 0,
 int maxTeams = 0,
 String sportType = 'Football',
 String governorate = '',
 bool isArabic = true,
 String? date,
 }) async {
 final link = '$_baseUrl/championship/$id';
 final translatedSport = isArabic
 ? (sportType == 'Football' ? 'كرة القدم' : (sportType == 'Padel' ? 'بادل' : sportType))
 : sportType;

 final start = startDateStr ?? date ?? '';
 final end = endDateStr ?? '';
 final dateDisplay = end.isNotEmpty ? 'من $start إلى $end' : start;

 final String text = isArabic
 ? '*دعوة للمشاركة في بطولة VSP الرياضية!*\n\n'
 '*اسم البطولة:* $name\n'
 '*المحافظة:* ${governorate.isNotEmpty ? governorate : "مصر"}\n'
 '*الرياضة:* $translatedSport\n'
 '*الموعد:* $dateDisplay\n'
 '*الجائزة الكبرى:* ${grandPrize.toInt()} ج.م\n'
 '*رسوم الدخول:* ${entryFee.toInt()} ج.م\n'
 '*الفرق المسجلة:* $joinedTeamsCount / $maxTeams فريق\n\n'
 'انضم إلى البطولة وسجّل فريقك الآن عبر تطبيق VSP:\n'
 '$link'
 : '*VSP Tournament Invitation!*\n\n'
 '*Tournament:* $name\n'
 '*Governorate:* ${governorate.isNotEmpty ? governorate : "Egypt"}\n'
 '*Sport:* $translatedSport\n'
 '*Dates:* ${end.isNotEmpty ? "$start to $end" : start}\n'
 '*Grand Prize:* ${grandPrize.toInt()} EGP\n'
 '*Entry Fee:* ${entryFee.toInt()} EGP\n'
 '*Teams Registered:* $joinedTeamsCount / $maxTeams Teams\n\n'
 'Join the tournament & register your team now on VSP:\n'
 '$link';

 await SharePlus.instance.share(ShareParams(
 text: text,
 subject: isArabic ? 'دعوة بطولة: $name' : 'Tournament Invite: $name',
 ));
 }

 /// Share championship using a Championship object directly with exact database numbers
 static Future<void> shareChampionshipObject({
 required BuildContext context,
 required dynamic championship,
 }) async {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 // Use effective start date: if tournament has already started, show today's date
 final now = DateTime.now();
 final rawStart = championship.startDate as DateTime;
 final effectiveStart = now.isAfter(rawStart) ? now : rawStart;

 final startDateStr = AppDateFormatter.formatDayMonth(effectiveStart, isArabic ? 'ar' : 'en');
 final endDateStr = AppDateFormatter.formatDayMonth(championship.endDate, isArabic ? 'ar' : 'en');

 await shareChampionship(
 id: championship.id.toString(),
 name: championship.name.toString(),
 startDateStr: startDateStr,
 endDateStr: endDateStr,
 grandPrize: (championship.grandPrize as num?)?.toDouble() ?? 0.0,
 entryFee: (championship.entryFee as num?)?.toDouble() ?? 0.0,
 joinedTeamsCount: (championship.joinedTeams as List?)?.length ?? 0,
 maxTeams: (championship.maxTeams as num?)?.toInt() ?? 0,
 sportType: championship.sportType?.toString() ?? 'Football',
 governorate: championship.governorate?.toString() ?? '',
 isArabic: isArabic,
 );
 }

 /// Share Team details via native share sheet
 static Future<void> shareTeam(BuildContext context, {
 required String teamId,
 required String teamName,
 required String governorate,
 }) async {
 final link = getTeamLink(teamId);
 final text = 'Checkout this team on VSP!\n\n'
 'Team: $teamName\n'
 'Governorate: $governorate\n\n'
 'Tap to view: $link';

 await SharePlus.instance.share(ShareParams(text: text, subject: 'View Team on VSP'));
 }

 /// Share Team Link with branding and localized text
 static Future<void> shareTeamLink(String teamId, String teamName) async {
 final link = getTeamLink(teamId);
 final text = 'انضم إلى مجموعتنا الرياضية على VSP!\n'
 'Check out our sports team on VSP!\n\n'
 'فريق: $teamName\n'
 'Team: $teamName\n\n'
 'رابط الفريق / Team Link:\n'
 '$link';

 await SharePlus.instance.share(ShareParams(text: text, subject: 'VSP Sports Team: $teamName'));
 }

 /// Generic text sharing
 Future<void> shareText(String text, {String? subject}) async {
 await SharePlus.instance.share(ShareParams(text: text, subject: subject));
 }
}
