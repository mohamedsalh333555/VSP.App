import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';
import '../../utils/app_date_formatter.dart';
import 'tournament_bracket_engine.dart';
import 'tournament_draw_notifier.dart';
import 'tournament_group_advancer.dart';
import 'tournament_stats_coordinator.dart';

/// Coordinates fixture generation for Knockout, Round-Robin League, and Group stages,
/// as well as advancing group stage qualifiers into knockout brackets.
class TournamentFixtureCoordinator {
  final SupabaseClient? _client;
  final Future<List<Team>> Function(List<String> ids)? _getTeamsByIds;
  final TournamentStatsCoordinator? _statsCoordinator;
  final TournamentDrawNotifier? _drawNotifier;
  final TournamentGroupAdvancer? _groupAdvancer;

  TournamentFixtureCoordinator({
    SupabaseClient? client,
    Future<List<Team>> Function(List<String> ids)? getTeamsByIds,
    TournamentStatsCoordinator? statsCoordinator,
    TournamentDrawNotifier? drawNotifier,
    TournamentGroupAdvancer? groupAdvancer,
  })  : _client = client,
        _getTeamsByIds = getTeamsByIds,
        _statsCoordinator = statsCoordinator,
        _drawNotifier = drawNotifier,
        _groupAdvancer = groupAdvancer;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  TournamentStatsCoordinator get _statsCoord =>
      _statsCoordinator ?? TournamentStatsCoordinator(client: _client);
  TournamentDrawNotifier get _notifier =>
      _drawNotifier ??
      TournamentDrawNotifier(
        client: _client,
        getTeamsByIds: _getTeamsByIds,
      );
  TournamentGroupAdvancer get _advancer =>
      _groupAdvancer ??
      TournamentGroupAdvancer(
        client: _client,
        statsCoordinator: _statsCoord,
      );

  Future<List<Team>> _fetchTeams(List<String> ids) async {
    if (_getTeamsByIds != null) return _getTeamsByIds(ids);
    if (ids.isEmpty) return [];
    try {
      final response = await _supabase
          .from('teams')
          .select('*, team_members(user_id, users(profile_image_url))')
          .inFilter('id', ids);

      final List<Team> teams = [];
      for (final doc in (response as List)) {
        final teamId = doc['id'].toString();
        final membersList = doc['team_members'] as List? ?? [];
        final List<String> memberUids = [];
        final List<String> playerImages = [];

        for (var m in membersList) {
          final uid = m['user_id']?.toString();
          if (uid != null) memberUids.add(uid);
          final userMap = m['users'];
          if (userMap is Map && userMap['profile_image_url'] != null) {
            playerImages.add(userMap['profile_image_url'].toString());
          }
        }

        final data = Map<String, dynamic>.from(doc);
        data['memberUids'] = memberUids;
        data['playerImages'] = playerImages;
        data['playersCount'] = memberUids.length;

        teams.add(Team.fromFirestore(data, teamId));
      }
      return teams;
    } catch (e) {
      debugPrint('Error getting teams by IDs: $e');
      return [];
    }
  }

  /// Generates knockout fixtures (supports BYE logic and power-of-two expansion).
  Future<void> generateFixtures(String championshipId) async {
    try {
      // 1. First attempt atomic server-side generation
      try {
        final rpcRes = await _supabase.rpc(
          'generate_tournament_bracket_atomic',
          params: {'p_championship_id': championshipId},
        );
        if (rpcRes is Map && rpcRes['success'] == true) {
          VSPLogger.i(
            'Tournament Fixtures generated via atomic server function: $rpcRes',
          );
          sendDrawNotifications(championshipId);
          return;
        }
      } catch (atomicErr) {
        VSPLogger.w(
          'generate_tournament_bracket_atomic fallback to client generator: $atomicErr',
        );
      }

      final champDoc = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champDoc == null) throw Exception('البطولة لا توجد.');

      final bool isPaidTourney = (champDoc['entry_fee'] != null &&
          (champDoc['entry_fee'] as num) > 0);
      final List<String> teamIds = isPaidTourney
          ? List<String>.from(champDoc['paid_teams'] ?? [])
          : List<String>.from(
              champDoc['joined_teams'] ?? champDoc['joinedTeams'] ?? []);
      final int totalTeams = teamIds.length;
      if (totalTeams < 2) {
        throw Exception(
          isPaidTourney
              ? 'يجب وجود فريقين مسددين لرسوم الاشتراك على الأقل لبدء البطولة.'
              : 'يجب وجود فريقين على الأقل لبدء البطولة.',
        );
      }

      final String? rawStartDate =
          champDoc['start_date'] ?? champDoc['startDate'];
      if (rawStartDate != null) {
        final startDate = DateTime.parse(rawStartDate);
        if (DateTime.now().isBefore(startDate)) {
          final formattedDate =
              AppDateFormatter.formatFullDate(startDate, 'ar');
          throw Exception(
            'لا يمكن بدء البطولة أو إطلاق القرعة قبل الموعد المعلن للفرق ($formattedDate) لالتزام اللاعبين واستعدادهم.',
          );
        }
      }

      final int configuredMaxTeams =
          champDoc['max_teams'] ?? champDoc['maxTeams'] ?? 16;
      final int bracketCapacity =
          TournamentBracketEngine.computeBracketCapacity(
        totalTeams,
        configuredMaxTeams,
      );

      final teams = await _fetchTeams(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};

      final shuffledIds = List<String>.from(teamIds)..shuffle(Random());
      final List<String?> slots = List.generate(bracketCapacity, (index) {
        return index < shuffledIds.length ? shuffledIds[index] : null;
      });

      // Delegate all bracket computation to the pure engine
      final allMatchesToInsert = TournamentBracketEngine.buildKnockoutMatchList(
        championshipId: championshipId,
        bracketCapacity: bracketCapacity,
        slots: slots,
        teamMap: teamMap,
      );
      if (allMatchesToInsert.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(allMatchesToInsert);
      }

      await _supabase
          .from('championships')
          .update({'status': 'ongoing'})
          .eq('id', championshipId);

      sendDrawNotifications(championshipId);

      debugPrint(
        'Tournament Fixtures generated successfully with BYE logic for $championshipId ($totalTeams teams)',
      );
    } catch (e) {
      debugPrint('Error generating fixtures: $e');
      rethrow;
    }
  }

  /// Generates round-robin league fixtures.
  Future<void> generateLeagueFixtures(String championshipId) async {
    try {
      try {
        await _supabase.rpc(
          'prepare_tournament_bracket',
          params: {'p_championship_id': championshipId},
        );
      } catch (e) {
        debugPrint('prepare_tournament_bracket RPC notice: $e');
        try {
          await _supabase
              .from('tournament_matches')
              .delete()
              .eq('championship_id', championshipId);
        } catch (_) {}
      }

      final champDoc = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champDoc == null) throw Exception('البطولة غير موجودة');

      final List<String> teamIds = (champDoc['joined_teams'] as List? ??
              champDoc['joinedTeams'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          [];
      if (teamIds.length < 2) throw Exception('يجب وجود فريقين على الأقل لإنشاء الدوري');

      final teams = await _fetchTeams(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};
      final isTwoLegs =
          champDoc['is_two_legs'] == true || champDoc['isTwoLegs'] == true;

      // Delegate league fixture generation to the pure engine
      final matchesToInsert = TournamentBracketEngine.buildLeagueMatchList(
        championshipId: championshipId,
        teamIds: teamIds,
        teamMap: teamMap,
        isTwoLegs: isTwoLegs,
      );

      if (matchesToInsert.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(matchesToInsert);
      }

      await _supabase
          .from('championships')
          .update({'status': 'ongoing'})
          .eq('id', championshipId);
      debugPrint(
        'League Fixtures generated successfully (${matchesToInsert.length} matches)',
      );
    } catch (e) {
      debugPrint('Error generating league fixtures: $e');
      rethrow;
    }
  }

  /// Generates group stage fixtures.
  Future<void> generateGroupsFixtures(String championshipId) async {
    try {
      try {
        await _supabase.rpc(
          'prepare_tournament_bracket',
          params: {'p_championship_id': championshipId},
        );
      } catch (e) {
        debugPrint('prepare_tournament_bracket RPC notice: $e');
        try {
          await _supabase
              .from('tournament_matches')
              .delete()
              .eq('championship_id', championshipId);
        } catch (_) {}
      }

      final champDoc = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champDoc == null) throw Exception('البطولة غير موجودة');

      final List<String> teamIds = (champDoc['joined_teams'] as List? ??
              champDoc['joinedTeams'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          [];
      final int numGroups = int.tryParse(
            (champDoc['number_of_groups'] ?? champDoc['numberOfGroups'] ?? 2)
                .toString(),
          ) ??
          2;

      if (teamIds.length < numGroups * 2) {
        throw Exception(
          'عدد الفرق غير كافٍ لتقسيمهم على $numGroups مجموعات',
        );
      }

      final teams = await _fetchTeams(teamIds);
      final teamMap = {for (var t in teams) t.id: t.name};

      // Delegate group fixture generation to the pure engine
      final matchesToInsert = TournamentBracketEngine.buildGroupMatchList(
        championshipId: championshipId,
        teamIds: teamIds,
        teamMap: teamMap,
        numGroups: numGroups,
      );

      if (matchesToInsert.isNotEmpty) {
        await _supabase.from('tournament_matches').insert(matchesToInsert);
      }

      await _supabase
          .from('championships')
          .update({'status': 'ongoing'})
          .eq('id', championshipId);
      debugPrint('Group Stage Fixtures generated successfully');
    } catch (e) {
      debugPrint('Error generating groups fixtures: $e');
      rethrow;
    }
  }

  /// Automatic qualification from group stages to knockout elimination bracket.
  Future<void> advanceGroupsToKnockout(String championshipId) =>
      _advancer.advanceGroupsToKnockout(championshipId);

  /// Sends draw notification to members of all teams in the championship.
  Future<void> sendDrawNotifications(String championshipId) =>
      _notifier.sendDrawNotifications(championshipId);
}

