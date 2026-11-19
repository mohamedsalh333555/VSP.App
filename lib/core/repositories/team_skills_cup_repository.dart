import 'package:supabase_flutter/supabase_flutter.dart';

/// Reuses VSP's existing Supabase session and canonical teams.
class TeamSkillsCupRepository {
  final SupabaseClient _client;
  TeamSkillsCupRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listCups({String governorate = 'All'}) async {
    var query = _client.from('team_skills_cups')
        .select('id,name,governorate,stadium_id,starts_at,ends_at,max_teams,'
            'hospitality_fee,image_url,status,prizes')
        .inFilter('status', ['registration', 'live', 'completed']);
    if (governorate.isNotEmpty && governorate != 'All') {
      query = query.eq('governorate', governorate);
    }
    final rows = await query.order('starts_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Only open published cups named in an authentic Team Skills notification.
  static String? cupIdFromNotificationMetadata(Map<String, dynamic>? metadata) {
    if (metadata?['source'] != 'team_skills_cup') return null;
    final id = metadata?['cup_id']?.toString() ?? '';
    final valid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
    return valid ? id.toLowerCase() : null;
  }

  /// Only a fresh published cup in the registration state may expose write
  /// actions. A cached notification/card or a failed refresh never suffices.
  static bool registrationOpen(Map<String, dynamic>? latestCup) =>
      latestCup?['status'] == 'registration';

  /// The stadium's display name is read separately from the published cup.
  /// Missing venue access never changes the authoritative cup status.
  Future<String?> getVenueName(String stadiumId) async {
    if (stadiumId.isEmpty) return null;
    try {
      final row = await _client.from('stadiums')
          .select('name').eq('id', stadiumId).maybeSingle();
      final name = row?['name']?.toString().trim();
      return name == null || name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCupById(String cupId) async {
    final row = await _client.from('team_skills_cups')
        .select('id,name,governorate,stadium_id,starts_at,ends_at,max_teams,'
            'hospitality_fee,image_url,status,prizes')
        .eq('id', cupId)
        .inFilter('status', ['registration', 'live', 'completed'])
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }
  /// The existing team_members table is the source of player membership.
  /// The caller can show their team's registration state without captain rights.
  Future<Set<String>> getMemberTeamIds(String userId) async {
    final rows = await _client.from('team_members')
        .select('team_id').eq('user_id', userId);
    return (rows as List)
        .map((row) => row['team_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> getCaptainTeams(String userId) async {
    final rows = await _client.from('teams_public')
        .select('id,name,captain_id').eq('captain_id', userId);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// The captain may be the canonical teams.captain_id without a duplicate
  /// team_members row. Show them in the 5-person selector only after checking
  /// both current Auth identity and canonical team ownership.
  ///
  /// Drop phone/contact fields returned by the shared legacy roster RPC: the
  /// Team Skills selector only needs stable IDs and display names.
  static List<Map<String, dynamic>> normalizeRosterWithCaptain({
    required List<Map<String, dynamic>> members,
    required String? currentUserId,
    required String? captainUserId,
    String? captainName,
  }) {
    final seen = <String>{};
    final options = <Map<String, dynamic>>[];
    for (final member in members) {
      final uid = member['uid']?.toString();
      if (uid == null || uid.isEmpty || !seen.add(uid)) continue;
      options.add({
        'uid': uid,
        'name': member['name']?.toString() ?? '',
        'p_position': member['p_position']?.toString() ?? '',
      });
    }
    if (currentUserId != null && currentUserId.isNotEmpty &&
        captainUserId == currentUserId && seen.add(currentUserId)) {
      options.add({
        'uid': currentUserId,
        'name': captainName?.trim().isNotEmpty == true
            ? captainName!.trim() : 'قائد الفريق',
        'p_position': 'captain',
      });
    }
    return options;
  }

  Future<List<Map<String, dynamic>>> getRosterOptions(String teamId) async {
    final currentUserId = _client.auth.currentUser?.id;
    final rows = await _client.rpc('get_team_member_profiles',
        params: {'p_team_id': teamId});
    final rawMembers = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map)).toList();
    final canonicalTeam = await _client.from('teams_public')
        .select('captain_id').eq('id', teamId).maybeSingle();
    final captainUserId = canonicalTeam?['captain_id']?.toString();
    String? captainName;
    if (currentUserId != null && currentUserId == captainUserId &&
        !rawMembers.any((row) => row['uid']?.toString() == currentUserId)) {
      final profile = await _client.from('users')
          .select('name').eq('id', currentUserId).maybeSingle();
      captainName = profile?['name']?.toString();
    }
    return normalizeRosterWithCaptain(
      members: rawMembers,
      currentUserId: currentUserId,
      captainUserId: captainUserId,
      captainName: captainName,
    );
  }

  Future<String> registerTeam({
    required String cupId, required String teamId,
    required List<String> playerIds, required String goalkeeperId,
    required String representativeId,
  }) async {
    if (cupId.trim().isEmpty || teamId.trim().isEmpty ||
        playerIds.any((id) => id.trim().isEmpty || id != id.trim()) ||
        playerIds.length != 5 || playerIds.toSet().length != 5 ||
        !playerIds.contains(goalkeeperId) ||
        !playerIds.contains(representativeId)) {
      throw StateError('INVALID_TEAM_SKILLS_ROSTER');
    }
    final receipt = await _client.rpc('team_skills_register', params: {
      'p_cup_id': cupId, 'p_team_id': teamId,
      'p_player_ids': playerIds, 'p_goalkeeper_id': goalkeeperId,
      'p_representative_id': representativeId,
    });
    if (receipt is! String || receipt.isEmpty) {
      throw StateError('TEAM_SKILLS_REGISTRATION_NOT_CONFIRMED');
    }
    return receipt;
  }

  /// A failed network response may still have committed the registration.
  /// Confirm success only from the captain's own team and application.
  static Map<String, dynamic>? findCaptainRegistration(
    List<Map<String, dynamic>> registrations, {
    required String teamId,
    required String captainId,
  }) {
    if (teamId.trim().isEmpty || captainId.trim().isEmpty) return null;
    final matches = registrations.where((row) =>
        row['team_id']?.toString() == teamId &&
        row['captain_id']?.toString() == captainId &&
        const {'pending', 'waitlist', 'approved'}
            .contains(row['status']?.toString())).take(2).toList();
    // A duplicated or contradictory live application must not promote the
    // first matching page row to a confirmed captain registration.
    return matches.length == 1 ? matches.single : null;
  }
  /// A successful HTTP response is not enough to confirm withdrawal.
  /// Read a terminal status for this exact captain and registration.
  static bool isCaptainWithdrawalConfirmed(
    List<Map<String, dynamic>> registrations, {
    required String registrationId,
    required String captainId,
  }) {
    if (registrationId.trim().isEmpty || captainId.trim().isEmpty) {
      return false;
    }
    // A repeated receipt with contradictory statuses or captains must not
    // be presented as a confirmed withdrawal, even when one row says yes.
    final receipts = registrations
        .where((row) => row['id']?.toString() == registrationId)
        .toList(growable: false);
    return receipts.length == 1 &&
        receipts.any((row) =>
            row['captain_id']?.toString() == captainId &&
            row['status'] == 'withdrawn');
  }

  /// UI-only eligibility preview; the server checks canonical captain,
  /// actual account status, event state, money settlement and current roster.
  static bool canWithdrawRegistration({
    required String? cupStatus,
    required String? status,
    required String? captainId,
    required String? viewerId,
    required String? hospitalityStatus,
    required bool hasCheckedIn,
  }) =>
      cupStatus == 'registration' &&
      (status == 'pending' || status == 'waitlist') &&
      viewerId != null && viewerId.isNotEmpty &&
      captainId == viewerId &&
      hospitalityStatus == 'unpaid' && !hasCheckedIn;

  /// Captain-only withdrawal of a pending/waitlisted application.
  /// The RPC is authoritative and audits the resulting freed roster/seat.
  /// Never treat network success alone as proof of a withdrawn registration.
  Future<void> withdrawRegistration(String registrationId) async {
    if (registrationId.trim().isEmpty) {
      throw StateError('TEAM_SKILLS_REGISTRATION_ID_REQUIRED');
    }
    await _client.rpc('team_skills_withdraw_registration',
      params: {'p_registration_id': registrationId});
  }

  /// Editable only before approval and settlement. Server ownership checks,
  /// current team membership and audit logging remain authoritative.
  static bool canCorrectRoster({
    required String? cupStatus,
    required String? status,
    required String? captainId,
    required String? viewerId,
    required String? hospitalityStatus,
    required bool hasCheckedIn,
  }) => canWithdrawRegistration(
    cupStatus: cupStatus,
    status: status,
    captainId: captainId,
    viewerId: viewerId,
    hospitalityStatus: hospitalityStatus,
    hasCheckedIn: hasCheckedIn,
  );

  Future<List<Map<String, dynamic>>> getActiveRoster(
      String registrationId) async {
    if (registrationId.trim().isEmpty) {
      throw StateError('TEAM_SKILLS_REGISTRATION_ID_REQUIRED');
    }
    final rows = await _client.from('team_skills_roster')
        .select('player_id,position')
        .eq('registration_id', registrationId)
        .eq('active', true)
        .order('player_id');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Captain can atomically replace their five players (including keeper and
  /// 1v1 representative) while the request is pending or waitlisted.
  Future<void> correctRoster({
    required String registrationId,
    required List<String> playerIds,
    required String goalkeeperId,
    required String representativeId,
  }) async {
    if (registrationId.trim().isEmpty) {
      throw StateError('TEAM_SKILLS_REGISTRATION_ID_REQUIRED');
    }
    if (playerIds.any((id) => id.trim().isEmpty || id != id.trim()) ||
        playerIds.length != 5 || playerIds.toSet().length != 5 ||
        !playerIds.contains(goalkeeperId) ||
        !playerIds.contains(representativeId)) {
      throw StateError('INVALID_TEAM_SKILLS_ROSTER');
    }
    await _client.rpc('team_skills_correct_roster', params: {
      'p_registration_id': registrationId,
      'p_player_ids': playerIds,
      'p_goalkeeper_id': goalkeeperId,
      'p_representative_id': representativeId,
    });
  }

  Future<List<Map<String, dynamic>>> getRegistrations(String cupId) async {
    final rows = await _client.from('team_skills_registrations')
        .select('id,cup_id,team_id,captain_id,status,goalkeeper_id,representative_id,'
            'hospitality_payment_status,checked_in_at,created_at,withdrawal_reason,withdrawn_at')
        .eq('cup_id', cupId);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String cupId) async {
    final rows = await _client.from('team_skills_leaderboard')
        .select('cup_id,team_id,registration_id,points,completed_stages,all_stages_approved')
        .eq('cup_id', cupId).order('points', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Only approved measurements are visible to players. Pending, corrected
  /// and unverified score inputs stay within the judges/admin workstream.
  Future<List<Map<String, dynamic>>> getApprovedScores(String cupId) async {
    final rows = await _client.from('team_skills_scores')
        .select('registration_id,stage_no,computed_points')
        .eq('cup_id', cupId)
        .eq('status', 'approved')
        .order('stage_no');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, String>> getTeamNames(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client.from('teams_public')
        .select('id,name').inFilter('id', ids.toSet().toList());
    return {for (final row in (rows as List))
      row['id'].toString(): row['name']?.toString() ?? ''};
  }

  Future<List<Map<String, dynamic>>> getPhases(String cupId) async {
    final rows = await _client.from('team_skills_phases')
        .select('stage_no,name_ar,category,weight,metric')
        .eq('cup_id', cupId).order('stage_no');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTeamHistory(String teamId) async {
    final rows = await _client.from('team_skills_team_history')
        .select('cup_id,cup_name,governorate,team_id,award_type,player_id,announced_at')
        .eq('team_id',teamId).order('announced_at',ascending:false);
    return (rows as List).cast<Map<String,dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPlayerHistory(String playerId) async {
    final rows = await _client.from('team_skills_player_history')
        .select('cup_id,cup_name,award_type,team_id,player_id,announced_at')
        .eq('player_id',playerId).order('announced_at',ascending:false);
    return (rows as List).cast<Map<String,dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAwards(String cupId) async {
    final rows = await _client.from('team_skills_awards')
        .select('cup_id,award_type,team_id,player_id,announced_at')
        .eq('cup_id', cupId);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
