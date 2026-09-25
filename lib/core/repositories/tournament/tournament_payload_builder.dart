/// Pure domain helper for constructing championship database payloads.
/// Handles all camelCase → snake_case field mapping and default values.
/// Contains no Supabase dependencies — all methods are stateless and testable.
class TournamentPayloadBuilder {
  const TournamentPayloadBuilder._();

  /// Normalizes the championship type string to the DB-accepted lowercase value.
  /// Maps all variations to 'groups', 'league', '1v1', or 'cup'.
  static String normalizeType(String rawType) {
    final lower = rawType.trim().toLowerCase();
    if (lower == 'groupsandknockout' ||
        lower == 'groups_and_knockout' ||
        lower == 'groups') {
      return 'groups';
    }
    if (lower == 'league') return 'league';
    if (lower == '1v1') return '1v1';
    if (lower == 'knockout') return 'knockout';
    if (lower == 'tournament') return 'tournament';
    return 'cup';
  }

  /// Builds the Postgres INSERT payload for a new championship.
  /// [data] may use camelCase or snake_case keys — both are handled.
  /// [isAdminApproved] sets the `is_approved` flag directly (for admin/co-founder creators).
  /// [fallbackOwnerId] is used when no owner_id is present in [data].
  static Map<String, dynamic> buildCreatePayload(
    Map<String, dynamic> data, {
    required bool isAdminApproved,
    required String fallbackOwnerId,
  }) {
    final sanitized = Map<String, dynamic>.from(data)
      ..remove('joinedTeams')
      ..remove('joined_teams')
      ..remove('status')
      ..remove('creatorId')
      ..remove('creator_id');

    final rawType = (sanitized['type'] ?? 'Cup').toString();

    return {
      'name': sanitized['name'],
      'type': normalizeType(rawType),
      'sport_type': sanitized['sportType'] ?? sanitized['sport_type'] ?? 'Football',
      'logo_url': sanitized['logoUrl'] ?? sanitized['logo_url'] ?? '',
      'start_date': sanitized['startDate'] ?? sanitized['start_date'],
      'end_date': sanitized['endDate'] ?? sanitized['end_date'],
      'entry_fee': sanitized['entryFee'] ?? sanitized['entry_fee'] ?? 0.0,
      'grand_prize': sanitized['grandPrize'] ?? sanitized['grand_prize'] ?? 0.0,
      'max_teams': sanitized['maxTeams'] ?? sanitized['max_teams'] ?? 16,
      'owner_id': _resolveOwnerId(sanitized, fallbackOwnerId),
      'governorate': sanitized['governorate'] ?? 'Cairo',
      'rules': sanitized['rules'] ?? '',
      'status': 'open',
      'is_approved': isAdminApproved,
      'joined_teams': [],
      'paid_teams': [],
      'payment_methods': sanitized['paymentMethods'] ?? ['cash'],
      // Flat settings columns
      'max_players_per_team':
          sanitized['maxPlayersPerTeam'] ?? sanitized['max_players_per_team'] ?? 11,
      'min_players_per_team':
          sanitized['minPlayersPerTeam'] ?? sanitized['min_players_per_team'] ?? 5,
      'winning_points': sanitized['winningPoints'] ?? sanitized['winning_points'] ?? 3,
      'draw_points': sanitized['drawPoints'] ?? sanitized['draw_points'] ?? 1,
      'loss_points': sanitized['lossPoints'] ?? sanitized['loss_points'] ?? 0,
      'match_duration': sanitized['matchDuration'] ?? sanitized['match_duration'] ?? 30,
      'is_back_and_forth':
          sanitized['isBackAndForth'] ?? sanitized['is_back_and_forth'] ?? false,
      'trophy_medals': sanitized['trophyMedals'] ?? sanitized['trophy_medals'] ?? true,
      'red_card_suspension':
          sanitized['redCardSuspension'] ?? sanitized['red_card_suspension'] ?? true,
      'fair_play_scoring':
          sanitized['fairPlayScoring'] ?? sanitized['fair_play_scoring'] ?? false,
      if (sanitized.containsKey('template_type') || sanitized.containsKey('templateType'))
        'template_type': sanitized['template_type'] ?? sanitized['templateType'],
      'number_of_groups': sanitized['number_of_groups'] ?? sanitized['numberOfGroups'] ?? (normalizeType(rawType) == 'groups' ? 4 : 1),
      'qualifying_per_group': sanitized['qualifying_per_group'] ?? sanitized['qualifyingPerGroup'] ?? 2,
    };
  }

  /// Builds the Postgres UPDATE payload for an existing championship.
  /// Only includes fields present in [data] to avoid partial overwrites.
  /// Supports both top-level keys (camelCase/snake_case) and a nested 'settings' map.
  static Map<String, dynamic> buildUpdatePayload(Map<String, dynamic> data) {
    final pgData = <String, dynamic>{};

    // Helper: sets pgKey if any of sourceKeys is found in data
    void pick(String pgKey, List<String> sourceKeys) {
      for (final key in sourceKeys) {
        if (data.containsKey(key)) {
          pgData[pgKey] = data[key];
          return;
        }
      }
    }

    pick('name', ['name']);
    if (data.containsKey('type')) {
      pgData['type'] = normalizeType(data['type'].toString());
    }
    pick('sport_type', ['sportType', 'sport_type']);
    pick('logo_url', ['logoUrl', 'logo_url']);
    pick('start_date', ['startDate', 'start_date']);
    pick('end_date', ['endDate', 'end_date']);
    pick('entry_fee', ['entryFee', 'entry_fee']);
    pick('grand_prize', ['grandPrize', 'grand_prize']);
    pick('max_teams', ['maxTeams', 'max_teams']);
    pick('governorate', ['governorate']);
    pick('rules', ['rules']);
    pick('payment_methods', ['paymentMethods', 'payment_methods']);
    pick('max_players_per_team', ['maxPlayersPerTeam', 'max_players_per_team']);
    pick('min_players_per_team', ['minPlayersPerTeam', 'min_players_per_team']);
    pick('winning_points', ['winningPoints', 'winning_points']);
    pick('draw_points', ['drawPoints', 'draw_points']);
    pick('loss_points', ['lossPoints', 'loss_points']);
    pick('match_duration', ['matchDuration', 'match_duration']);
    pick('is_back_and_forth', ['isBackAndForth', 'is_back_and_forth']);
    pick('trophy_medals', ['trophyMedals', 'trophy_medals']);
    pick('red_card_suspension', ['redCardSuspension', 'red_card_suspension']);
    pick('fair_play_scoring', ['fairPlayScoring', 'fair_play_scoring']);

    // Support nested 'settings' map as a secondary source
    if (data.containsKey('settings') && data['settings'] is Map) {
      final settings = data['settings'] as Map;
      void pickFromSettings(String pgKey, List<String> settingsKeys) {
        for (final key in settingsKeys) {
          if (settings.containsKey(key) && !pgData.containsKey(pgKey)) {
            pgData[pgKey] = settings[key];
            return;
          }
        }
      }

      pickFromSettings('max_players_per_team', ['maxPlayers', 'max_players']);
      pickFromSettings('min_players_per_team', ['minPlayers', 'min_players']);
      pickFromSettings('winning_points', ['winningPoints', 'winning_points']);
      pickFromSettings('draw_points', ['drawPoints', 'draw_points']);
      pickFromSettings('loss_points', ['lossPoints', 'loss_points']);
      pickFromSettings('match_duration', ['matchDuration', 'match_duration']);
      pickFromSettings('is_back_and_forth', ['isBackAndForth', 'is_back_and_forth']);
      pickFromSettings('trophy_medals', ['trophyMedals', 'trophy_medals']);
      pickFromSettings('red_card_suspension', ['redCardSuspension', 'red_card_suspension']);
      pickFromSettings('fair_play_scoring', ['fairPlayScoring', 'fair_play_scoring']);
    }

    return pgData;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static String _resolveOwnerId(Map<String, dynamic> data, String fallback) {
    final fromCamel = data['ownerId']?.toString() ?? '';
    final fromSnake = data['owner_id']?.toString() ?? '';
    if (fromCamel.isNotEmpty) return fromCamel;
    if (fromSnake.isNotEmpty) return fromSnake;
    return fallback;
  }
}
