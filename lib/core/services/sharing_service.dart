import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class SharingService {
  // Base URL for deep linking
  // In production, this would be your verified domain
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
    final text = 'Join our match at VSP!\n\n'
        '🏆 Team: $teamName\n'
        '📍 Stadium: $stadiumName\n'
        '📅 Date: $date\n\n'
        'Tap to join: $link';

    await SharePlus.instance.share(ShareParams(text: text, subject: 'Join Match on VSP'));
  }

  /// Share championship details
  static Future<void> shareChampionship({
    required String id,
    required String name,
    required String date,
  }) async {
    final link = '$_baseUrl/championship/$id';
    final text = 'Check out this tournament on VSP!\n\n'
        '⚽ Tournament: $name\n'
        '📅 Starts: $date\n\n'
        'View details: $link';

    await SharePlus.instance.share(ShareParams(text: text, subject: 'VSP Championship'));
  }

  /// Share Team details via native share sheet
  static Future<void> shareTeam(BuildContext context, {
    required String teamId,
    required String teamName,
    required String governorate,
  }) async {
    final link = getTeamLink(teamId);
    final text = 'Checkout this team on VSP!\n\n'
        '🛡 Team: $teamName\n'
        '📍 Governorate: $governorate\n\n'
        'Tap to view: $link';

    await SharePlus.instance.share(ShareParams(text: text, subject: 'View Team on VSP'));
  }

  /// Share Team Link with branding and localized text
  static Future<void> shareTeamLink(String teamId, String teamName) async {
    final link = getTeamLink(teamId);
    final text = 'انضم إلى مجموعتنا الرياضية على VSP! ⚽\n'
        'Check out our sports team on VSP!\n\n'
        '🛡️ فريق: $teamName\n'
        '🛡️ Team: $teamName\n\n'
        'رابط الفريق / Team Link:\n'
        '$link';

    await SharePlus.instance.share(ShareParams(text: text, subject: 'VSP Sports Team: $teamName'));
  }

  /// Generic text sharing (Fixed for CMO Social Strategy)
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}
