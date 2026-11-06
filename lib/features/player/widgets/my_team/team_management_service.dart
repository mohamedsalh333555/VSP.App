import '../../../../core/models/user_model.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../data/models.dart';

/// Pure domain helper for team creation, update payload building, and error formatting.
class TeamManagementService {
  const TeamManagementService._();

  /// Builds creation payload for a brand new team.
  static Map<String, dynamic> buildCreateTeamPayload({
    required String name,
    required String sportType,
    required UserModel user,
    String? logoUrl,
    required List<UserModel> members,
  }) {
    // Deduplicate members before deriving both parallel roster arrays.
    final seen = <String>{user.uid};
    final uniqueMembers = members.where((member) => seen.add(member.uid)).toList();
    final List<String> memberUids = [user.uid, ...uniqueMembers.map((m) => m.uid)];
    final List<String> playerImages = [
      user.profileImageUrl ?? '',
      ...uniqueMembers.map((m) => m.profileImageUrl ?? ''),
    ];

    return {
      'name': name.trim(),
      'sportType': sportType,
      'captainName': user.name ?? 'Captain',
      'captainImageUrl': user.profileImageUrl ?? '',
      'logoUrl': logoUrl ?? '',
      'captainPhone': PhoneUtils.normalize(user.phone ?? ''),
      'memberUids': memberUids,
      'playerImages': playerImages,
      'playersCount': memberUids.length,
      'stadium': 'TBD',
      'date': 'Upcoming',
      'points': 0,
      'wins': 0,
      'championshipsWon': 0,
      'unlockedBadges': <String>[],
      'currentWinningStreak': 0,
    };
  }

  /// Builds update payload for an existing team while preserving captain primacy.
  static Map<String, dynamic> buildUpdateTeamPayload({
    required String name,
    required String sportType,
    required Team existingTeam,
    UserModel? user,
    String? logoUrl,
    required List<UserModel> members,
  }) {
    final captainUid = existingTeam.memberUids.isNotEmpty
        ? existingTeam.memberUids.first
        : (user?.uid ?? '');
    final seen = <String>{captainUid};
    final uniqueMembers = members.where((member) => seen.add(member.uid)).toList();
    final List<String> memberUids = [
      captainUid,
      ...uniqueMembers.map((m) => m.uid),
    ];
    final List<String> playerImages = [
      user?.profileImageUrl ?? (existingTeam.playerImages.isNotEmpty ? existingTeam.playerImages.first : ''),
      ...uniqueMembers.map((m) => m.profileImageUrl ?? ''),
    ];

    return {
      'name': name.trim(),
      'sportType': sportType,
      'logoUrl': logoUrl ?? existingTeam.logoUrl,
      'captainImageUrl': user?.profileImageUrl ?? existingTeam.captainImageUrl,
      'memberUids': memberUids,
      'playerImages': playerImages,
      'playersCount': memberUids.length,
    };
  }

  /// Formats and localizes team error messages, especially tournament lockout constraints.
  static String formatTeamErrorMessage(dynamic error, {required bool isArabic}) {
    final errStr = error.toString().replaceAll('Exception:', '').trim();
    if (errStr.contains('active_match_or_tournament_error') || errStr.contains('team_in_tournament')) {
      return isArabic
          ? 'لا يمكن إتمام العملية لوجود مباريات قادمة أو بطولة نشطة!'
          : 'Cannot complete operation with upcoming matches or active tournament!';
    }
    return errStr;
  }
}
